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
public class TransactionHistoryItem {

    private UUID transactionId;
    private String transactionType;
    private String status;
    private LocalDate businessDate;
    private String description;
    private String entryType;
    private BigDecimal amount;
    private BigDecimal balanceAfter;
}
