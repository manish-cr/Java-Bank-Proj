package com.nexusbank.engine.service;

import com.nexusbank.engine.dto.request.CreateAccountRequest;
import com.nexusbank.engine.dto.response.AccountDetailResponse;
import com.nexusbank.engine.dto.response.CreateAccountResponse;
import com.nexusbank.engine.repository.AccountRepository;
import com.nexusbank.engine.repository.LedgerEntryRepository;
import jakarta.persistence.EntityManager;
import jakarta.persistence.ParameterMode;
import jakarta.persistence.StoredProcedureQuery;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class AccountManagementService {

    private final EntityManager entityManager;
    private final AccountRepository accountRepository;
    private final LedgerEntryRepository ledgerEntryRepository;

    @Transactional
    public CreateAccountResponse createAccount(CreateAccountRequest request) {
        log.info("Creating {} account for customer {}", request.getAccountType(), request.getCustomerId());

        StoredProcedureQuery query = entityManager
            .createStoredProcedureQuery("sp_create_account")
            .registerStoredProcedureParameter("p_customer_id", UUID.class, ParameterMode.IN)
            .registerStoredProcedureParameter("p_account_type", String.class, ParameterMode.IN)
            .registerStoredProcedureParameter("p_currency_code", String.class, ParameterMode.IN)
            .registerStoredProcedureParameter("p_interest_rate", BigDecimal.class, ParameterMode.IN)
            .registerStoredProcedureParameter("p_monthly_fee", BigDecimal.class, ParameterMode.IN)
            .registerStoredProcedureParameter("p_overdraft_limit", BigDecimal.class, ParameterMode.IN)
            .registerStoredProcedureParameter("p_original_principal", BigDecimal.class, ParameterMode.IN)
            .registerStoredProcedureParameter("p_loan_term_months", Integer.class, ParameterMode.IN)
            .registerStoredProcedureParameter("p_monthly_payment", BigDecimal.class, ParameterMode.IN)
            .setParameter("p_customer_id", request.getCustomerId())
            .setParameter("p_account_type", request.getAccountType())
            .setParameter("p_currency_code", request.getCurrencyCode() != null ? request.getCurrencyCode() : "USD")
            .setParameter("p_interest_rate", request.getInterestRate())
            .setParameter("p_monthly_fee", request.getMonthlyFee())
            .setParameter("p_overdraft_limit", request.getOverdraftLimit())
            .setParameter("p_original_principal", request.getOriginalPrincipal())
            .setParameter("p_loan_term_months", request.getLoanTermMonths())
            .setParameter("p_monthly_payment", request.getMonthlyPayment());

        @SuppressWarnings("unchecked")
        var result = (Object[]) query.getSingleResult();

        return CreateAccountResponse.builder()
            .accountId((UUID) result[0])
            .accountNumber((String) result[1])
            .status((String) result[2])
            .message((String) result[3])
            .build();
    }

    @Transactional(readOnly = true)
    public AccountDetailResponse getAccountDetail(UUID accountId) {
        var account = accountRepository.findById(accountId)
            .orElseThrow(() -> new RuntimeException("Account not found: " + accountId));

        var balance = ledgerEntryRepository.findCurrentBalance(accountId).orElse(BigDecimal.ZERO);

        var customer = account.getCustomer();
        var response = AccountDetailResponse.builder()
            .accountId(account.getAccountId())
            .accountNumber(account.getAccountNumber())
            .accountType(account.getAccountType())
            .currencyCode(account.getCurrencyCode())
            .status(account.getStatus())
            .currentBalance(balance)
            .openedAt(account.getOpenedAt())
            .customerId(customer.getCustomerId())
            .customerName(customer.getLegalName())
            .build();

        return response;
    }
}
