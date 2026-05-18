package com.nexusbank.engine.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class AccountBalanceResponse {

    private UUID accountId;
    private String accountNumber;
    private String accountType;
    private String currencyCode;
    private BigDecimal currentBalance;
    private LocalDate asOfDate;
}
