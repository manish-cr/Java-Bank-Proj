package com.nexusbank.engine.controller;

import com.nexusbank.engine.dto.response.AccountBalanceResponse;
import com.nexusbank.engine.dto.response.ErrorResponse;
import com.nexusbank.engine.dto.response.PagedResponse;
import com.nexusbank.engine.dto.response.TransactionHistoryItem;
import com.nexusbank.engine.service.AccountQueryService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.UUID;

@Slf4j
@RestController
@RequestMapping("/accounts")
@RequiredArgsConstructor
@Tag(name = "Account", description = "Account query operations")
public class AccountController {

    private final AccountQueryService accountQueryService;

    @GetMapping("/{accountId}/balance")
    @Operation(summary = "Get account balance",
               description = "Returns the current balance or balance as of a specific date")
    public ResponseEntity<AccountBalanceResponse> getBalance(
            @PathVariable UUID accountId,
            @Parameter(description = "Optional: date to get balance as of (YYYY-MM-DD)")
            @RequestParam(required = false)
            @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate asOfDate) {
        return ResponseEntity.ok(accountQueryService.getBalance(accountId, asOfDate));
    }

    @GetMapping("/{accountId}/transactions")
    @Operation(summary = "Get transaction history",
               description = "Returns paginated transaction history for an account within a date range")
    public ResponseEntity<PagedResponse<TransactionHistoryItem>> getTransactionHistory(
            @PathVariable UUID accountId,
            @Parameter(description = "Start date (YYYY-MM-DD), defaults to 1 month ago")
            @RequestParam(required = false)
            @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate fromDate,
            @Parameter(description = "End date (YYYY-MM-DD), defaults to today")
            @RequestParam(required = false)
            @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate toDate,
            @Parameter(description = "Page number (0-based)")
            @RequestParam(defaultValue = "0") int page,
            @Parameter(description = "Page size")
            @RequestParam(defaultValue = "20") int size) {
        return ResponseEntity.ok(
            accountQueryService.getTransactionHistory(accountId, fromDate, toDate, page, size));
    }
}
