package com.nexusbank.engine.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class AccountDetailResponse {

    private UUID accountId;
    private String accountNumber;
    private String accountType;
    private String currencyCode;
    private String status;
    private BigDecimal currentBalance;
    private LocalDateTime openedAt;

    private UUID customerId;
    private String customerName;

    private BigDecimal interestRate;
    private BigDecimal monthlyFee;
    private BigDecimal overdraftLimit;
    private BigDecimal principalOutstanding;
    private BigDecimal monthlyPayment;
    private LocalDate nextPaymentDate;
    private Integer daysPastDue;
}
