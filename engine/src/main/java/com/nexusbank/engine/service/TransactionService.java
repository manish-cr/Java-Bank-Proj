package com.nexusbank.engine.service;

import com.nexusbank.engine.dto.request.DepositRequest;
import com.nexusbank.engine.dto.request.ReverseTransactionRequest;
import com.nexusbank.engine.dto.request.WithdrawalRequest;
import com.nexusbank.engine.dto.response.TransactionResult;
import jakarta.persistence.EntityManager;
import jakarta.persistence.ParameterMode;
import jakarta.persistence.StoredProcedureQuery;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class TransactionService {

    private final EntityManager entityManager;

    @Transactional
    public TransactionResult performDeposit(DepositRequest request) {
        log.info("Processing deposit: account={}, amount={}", request.getToAccountId(), request.getAmount());

        StoredProcedureQuery query = entityManager
            .createStoredProcedureQuery("sp_perform_deposit")
            .registerStoredProcedureParameter("p_idempotency_key", UUID.class, ParameterMode.IN)
            .registerStoredProcedureParameter("p_to_account_id", UUID.class, ParameterMode.IN)
            .registerStoredProcedureParameter("p_amount", java.math.BigDecimal.class, ParameterMode.IN)
            .registerStoredProcedureParameter("p_description", String.class, ParameterMode.IN)
            .setParameter("p_idempotency_key", request.getIdempotencyKey())
            .setParameter("p_to_account_id", request.getToAccountId())
            .setParameter("p_amount", request.getAmount())
            .setParameter("p_description",
                request.getDescription() != null ? request.getDescription() : "Cash deposit");

        @SuppressWarnings("unchecked")
        var result = (Object[]) query.getSingleResult();

        return TransactionResult.builder()
            .transactionId((UUID) result[0])
            .status((String) result[1])
            .message((String) result[2])
            .timestamp(LocalDateTime.now())
            .build();
    }

    @Transactional
    public TransactionResult performWithdrawal(WithdrawalRequest request) {
        log.info("Processing withdrawal: account={}, amount={}", request.getFromAccountId(), request.getAmount());

        StoredProcedureQuery query = entityManager
            .createStoredProcedureQuery("sp_perform_withdrawal")
            .registerStoredProcedureParameter("p_idempotency_key", UUID.class, ParameterMode.IN)
            .registerStoredProcedureParameter("p_from_account_id", UUID.class, ParameterMode.IN)
            .registerStoredProcedureParameter("p_amount", java.math.BigDecimal.class, ParameterMode.IN)
            .registerStoredProcedureParameter("p_description", String.class, ParameterMode.IN)
            .setParameter("p_idempotency_key", request.getIdempotencyKey())
            .setParameter("p_from_account_id", request.getFromAccountId())
            .setParameter("p_amount", request.getAmount())
            .setParameter("p_description",
                request.getDescription() != null ? request.getDescription() : "Cash withdrawal");

        @SuppressWarnings("unchecked")
        var result = (Object[]) query.getSingleResult();

        return TransactionResult.builder()
            .transactionId((UUID) result[0])
            .status((String) result[1])
            .message((String) result[2])
            .timestamp(LocalDateTime.now())
            .build();
    }
}
