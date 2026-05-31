package com.nexusbank.engine.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class LoanPaymentResponse {

    private UUID transactionId;
    private BigDecimal interestPortion;
    private BigDecimal principalPortion;
    private BigDecimal remainingPrincipal;
    private String status;
    private String message;
    private LocalDateTime timestamp;
}
