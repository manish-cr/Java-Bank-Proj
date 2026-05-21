package com.nexusbank.engine.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CreateAccountRequest {

    @NotNull(message = "Customer ID is required")
    private UUID customerId;

    @NotBlank(message = "Account type is required")
    private String accountType;

    private String currencyCode;

    private BigDecimal interestRate;
    private BigDecimal monthlyFee;
    private BigDecimal overdraftLimit;
    private BigDecimal originalPrincipal;
    private Integer loanTermMonths;
    private BigDecimal monthlyPayment;
}
