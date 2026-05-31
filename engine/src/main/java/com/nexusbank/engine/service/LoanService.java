package com.nexusbank.engine.service;

import com.nexusbank.engine.dto.request.LoanPaymentRequest;
import com.nexusbank.engine.dto.response.LoanPaymentResponse;
import jakarta.persistence.EntityManager;
import jakarta.persistence.ParameterMode;
import jakarta.persistence.StoredProcedureQuery;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class LoanService {

    private final EntityManager entityManager;

    @Transactional
    public LoanPaymentResponse makePayment(LoanPaymentRequest request) {
        log.info("Processing loan payment: loan={}, from={}, amount={}",
            request.getLoanAccountId(), request.getFromCheckingAccountId(), request.getPaymentAmount());

        StoredProcedureQuery query = entityManager
            .createStoredProcedureQuery("sp_make_loan_payment")
            .registerStoredProcedureParameter("p_loan_account_id", UUID.class, ParameterMode.IN)
            .registerStoredProcedureParameter("p_from_checking_id", UUID.class, ParameterMode.IN)
            .registerStoredProcedureParameter("p_payment_amount", BigDecimal.class, ParameterMode.IN)
            .registerStoredProcedureParameter("p_idempotency_key", UUID.class, ParameterMode.IN)
            .registerStoredProcedureParameter("p_description", String.class, ParameterMode.IN)
            .setParameter("p_loan_account_id", request.getLoanAccountId())
            .setParameter("p_from_checking_id", request.getFromCheckingAccountId())
            .setParameter("p_payment_amount", request.getPaymentAmount())
            .setParameter("p_idempotency_key", request.getIdempotencyKey())
            .setParameter("p_description",
                request.getDescription() != null ? request.getDescription() : "Loan payment");

        Object[] result = (Object[]) query.getSingleResult();

        return LoanPaymentResponse.builder()
            .transactionId((UUID) result[0])
            .interestPortion((BigDecimal) result[1])
            .principalPortion((BigDecimal) result[2])
            .remainingPrincipal((BigDecimal) result[3])
            .status((String) result[4])
            .message((String) result[5])
            .timestamp(LocalDateTime.now())
            .build();
    }
}
