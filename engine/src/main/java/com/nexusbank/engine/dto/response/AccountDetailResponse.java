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

    // Product-specific
    private BigDecimal interestRate;
    private BigDecimal monthlyFee;
    private BigDecimal overdraftLimit;
    private BigDecimal principalOutstanding;
    private BigDecimal monthlyPayment;
    private LocalDate nextPaymentDate;
    private Integer daysPastDue;

    // Rate info
    private String rateType;
    private String rateCode;
    private String compoundingFrequency;
    private BigDecimal interestAccruedPending;
    private BigDecimal interestAccruedYtd;

    // ARM fields
    private String referenceRateCode;
    private BigDecimal margin;
    private LocalDate nextRateAdjustment;
    private BigDecimal annualCap;
    private BigDecimal lifetimeCap;
    private BigDecimal lifetimeFloor;
}
