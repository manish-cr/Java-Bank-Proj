package com.nexusbank.engine.service;

import com.nexusbank.engine.dto.response.TransactionResult;
import com.nexusbank.engine.entity.Account;
import com.nexusbank.engine.repository.AccountRepository;
import jakarta.persistence.EntityManager;
import jakarta.persistence.ParameterMode;
import jakarta.persistence.StoredProcedureQuery;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.*;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.Executor;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class InterestAccrualService {

    private final EntityManager entityManager;
    private final AccountRepository accountRepository;
    private final Executor interestAccrualExecutor;

    @Async("interestAccrualExecutor")
    public CompletableFuture<Map<String, Object>> processAccount(UUID accountId) {
        Map<String, Object> result = new HashMap<>();
        result.put("accountId", accountId);

        try {
            StoredProcedureQuery query = entityManager
                .createStoredProcedureQuery("sp_accrue_daily_interest_for_account")
                .registerStoredProcedureParameter("p_account_id", UUID.class, ParameterMode.IN)
                .setParameter("p_account_id", accountId);

            Object[] spResult = (Object[]) query.getSingleResult();

            result.put("daysProcessed", spResult[1]);
            result.put("interestAccrued", spResult[2]);
            result.put("status", spResult[3]);
            result.put("message", spResult[4]);
            result.put("success", "SUCCESS".equals(spResult[3]) || "SKIPPED".equals(spResult[3]));
        } catch (Exception e) {
            log.error("Interest accrual failed for account {}: {}", accountId, e.getMessage());
            result.put("success", false);
            result.put("status", "ERROR");
            result.put("message", e.getMessage());
        }

        return CompletableFuture.completedFuture(result);
    }

    @Transactional
    public Map<String, Object> accrueDailyInterestForAllAccounts() {
        List<Account> accounts = accountRepository.findActiveByCustomerId(null);
        // Actually get all active savings accounts
        List<UUID> savingsAccountIds = accountRepository.findAll().stream()
            .filter(a -> "SAVINGS".equals(a.getAccountType()) && "ACTIVE".equals(a.getStatus()))
            .map(Account::getAccountId)
            .collect(Collectors.toList());

        log.info("Starting daily interest accrual for {} savings accounts", savingsAccountIds.size());

        List<CompletableFuture<Map<String, Object>>> futures = savingsAccountIds.stream()
            .map(this::processAccount)
            .collect(Collectors.toList());

        CompletableFuture.allOf(futures.toArray(new CompletableFuture[0])).join();

        List<Map<String, Object>> results = futures.stream()
            .map(CompletableFuture::join)
            .collect(Collectors.toList());

        long successCount = results.stream().filter(r -> (boolean) r.get("success")).count();
        long failCount = results.size() - successCount;
        BigDecimal totalInterest = results.stream()
            .filter(r -> r.get("interestAccrued") != null)
            .map(r -> (BigDecimal) r.get("interestAccrued"))
            .reduce(BigDecimal.ZERO, BigDecimal::add);

        Map<String, Object> summary = new HashMap<>();
        summary.put("totalAccounts", results.size());
        summary.put("successCount", successCount);
        summary.put("failCount", failCount);
        summary.put("totalInterestAccrued", totalInterest);
        summary.put("results", results);
        summary.put("timestamp", LocalDateTime.now());

        log.info("Daily interest accrual complete: {} success, {} fail, total interest: {}",
            successCount, failCount, totalInterest);

        return summary;
    }

    @Transactional
    public TransactionResult compoundInterest(UUID accountId) {
        log.info("Compounding interest for account {}", accountId);

        StoredProcedureQuery query = entityManager
            .createStoredProcedureQuery("sp_compound_interest")
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
    public Map<String, Object> compoundAllDueAccounts() {
        List<Account> savingsAccounts = accountRepository.findAll().stream()
            .filter(a -> "SAVINGS".equals(a.getAccountType()) && "ACTIVE".equals(a.getStatus()))
            .collect(Collectors.toList());

        List<Map<String, Object>> results = new ArrayList<>();
        int compounded = 0;
        int skipped = 0;

        // Check which accounts are due for compounding
        String checkSql = """
            SELECT pss.account_id, pss.compounding_frequency
            FROM product_state_savings pss
            WHERE pss.interest_accrued_pending > 0
              AND fn_is_compounding_date(pss.compounding_frequency)
            """;

        @SuppressWarnings("unchecked")
        List<Object[]> dueAccounts = entityManager.createNativeQuery(checkSql).getResultList();

        for (Object[] row : dueAccounts) {
            UUID accountId = (UUID) row[0];
            try {
                TransactionResult txnResult = compoundInterest(accountId);
                Map<String, Object> entry = new HashMap<>();
                entry.put("accountId", accountId);
                entry.put("status", txnResult.getStatus());
                entry.put("message", txnResult.getMessage());
                results.add(entry);

                if ("POSTED".equals(txnResult.getStatus())) compounded++;
                else skipped++;
            } catch (Exception e) {
                log.error("Compounding failed for account {}: {}", accountId, e.getMessage());
                Map<String, Object> entry = new HashMap<>();
                entry.put("accountId", accountId);
                entry.put("status", "ERROR");
                entry.put("message", e.getMessage());
                results.add(entry);
            }
        }

        Map<String, Object> summary = new HashMap<>();
        summary.put("compounded", compounded);
        summary.put("skipped", skipped);
        summary.put("results", results);
        summary.put("timestamp", LocalDateTime.now());

        log.info("Interest compounding complete: {} compounded, {} skipped", compounded, skipped);
        return summary;
    }
}
