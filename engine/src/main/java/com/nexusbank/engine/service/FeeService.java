package com.nexusbank.engine.service;

import com.nexusbank.engine.dto.response.TransactionResult;
import com.nexusbank.engine.entity.Account;
import com.nexusbank.engine.repository.AccountRepository;
import jakarta.persistence.EntityManager;
import jakarta.persistence.ParameterMode;
import jakarta.persistence.StoredProcedureQuery;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.*;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class FeeService {

    private final EntityManager entityManager;
    private final AccountRepository accountRepository;

    @Transactional
    public TransactionResult chargeMonthlyFee(UUID accountId) {
        log.info("Charging monthly fee for account {}", accountId);

        StoredProcedureQuery query = entityManager
            .createStoredProcedureQuery("sp_charge_monthly_fee")
            .registerStoredProcedureParameter("p_account_id", UUID.class, ParameterMode.IN)
            .registerStoredProcedureParameter("p_idempotency_key", UUID.class, ParameterMode.IN)
            .setParameter("p_account_id", accountId)
            .setParameter("p_idempotency_key", UUID.randomUUID());

        Object[] result = (Object[]) query.getSingleResult();

        return TransactionResult.builder()
            .transactionId((UUID) result[0])
            .status((String) result[1])
            .message((String) result[2])
            .timestamp(LocalDateTime.now())
            .build();
    }

    @Transactional
    public Map<String, Object> chargeAllMonthlyFees() {
        List<Account> checkingAccounts = accountRepository.findAll().stream()
            .filter(a -> "CHECKING".equals(a.getAccountType()) && "ACTIVE".equals(a.getStatus()))
            .collect(Collectors.toList());

        int charged = 0;
        int skipped = 0;
        int failed = 0;
        BigDecimal totalFees = BigDecimal.ZERO;
        List<Map<String, Object>> results = new ArrayList<>();

        for (Account account : checkingAccounts) {
            try {
                TransactionResult result = chargeMonthlyFee(account.getAccountId());
                Map<String, Object> entry = new HashMap<>();
                entry.put("accountId", account.getAccountId());
                entry.put("accountNumber", account.getAccountNumber());
                entry.put("status", result.getStatus());
                entry.put("message", result.getMessage());
                results.add(entry);

                if ("POSTED".equals(result.getStatus())) charged++;
                else if ("SKIPPED".equals(result.getStatus())) skipped++;
                else failed++;
            } catch (Exception e) {
                log.error("Monthly fee failed for account {}: {}", account.getAccountId(), e.getMessage());
                failed++;
                Map<String, Object> entry = new HashMap<>();
                entry.put("accountId", account.getAccountId());
                entry.put("status", "ERROR");
                entry.put("message", e.getMessage());
                results.add(entry);
            }
        }

        Map<String, Object> summary = new HashMap<>();
        summary.put("totalAccounts", checkingAccounts.size());
        summary.put("charged", charged);
        summary.put("skipped", skipped);
        summary.put("failed", failed);
        summary.put("results", results);
        summary.put("timestamp", LocalDateTime.now());

        log.info("Monthly fees complete: {} charged, {} skipped, {} failed", charged, skipped, failed);
        return summary;
    }

    @Transactional
    public TransactionResult chargeLateFee(UUID loanAccountId) {
        log.info("Charging late fee for loan account {}", loanAccountId);

        StoredProcedureQuery query = entityManager
            .createStoredProcedureQuery("sp_charge_late_fee")
            .registerStoredProcedureParameter("p_loan_account_id", UUID.class, ParameterMode.IN)
            .registerStoredProcedureParameter("p_idempotency_key", UUID.class, ParameterMode.IN)
            .setParameter("p_loan_account_id", loanAccountId)
            .setParameter("p_idempotency_key", UUID.randomUUID());

        Object[] result = (Object[]) query.getSingleResult();

        return TransactionResult.builder()
            .transactionId((UUID) result[0])
            .status((String) result[1])
            .message((String) result[2])
            .timestamp(LocalDateTime.now())
            .build();
    }
}
