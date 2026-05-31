package com.nexusbank.engine.dto.request;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;
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
public class LoanPaymentRequest {

    @NotNull(message = "Idempotency key is required")
    private UUID idempotencyKey;

    @NotNull(message = "Loan account ID is required")
    private UUID loanAccountId;

    @NotNull(message = "Checking account ID is required")
    private UUID fromCheckingAccountId;

    @NotNull(message = "Payment amount is required")
    @Positive(message = "Payment amount must be positive")
    private BigDecimal paymentAmount;

    @Size(max = 500)
    private String description;
}
