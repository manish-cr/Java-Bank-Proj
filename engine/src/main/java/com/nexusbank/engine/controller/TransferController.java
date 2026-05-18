package com.nexusbank.engine.controller;

import com.nexusbank.engine.dto.request.ReverseTransactionRequest;
import com.nexusbank.engine.dto.request.TransferRequest;
import com.nexusbank.engine.dto.response.ErrorResponse;
import com.nexusbank.engine.dto.response.TransactionResult;
import com.nexusbank.engine.service.TransferService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;

@Slf4j
@RestController
@RequestMapping("/transactions")
@RequiredArgsConstructor
@Tag(name = "Transfer", description = "Money transfer and reversal operations")
public class TransferController {

    private final TransferService transferService;

    @PostMapping("/transfers")
    @Operation(summary = "Transfer money between two accounts",
               description = "Atomically transfers funds with double-entry posting and idempotency protection")
    @ApiResponses(value = {
        @ApiResponse(responseCode = "200", description = "Transfer completed or duplicate request returned"),
        @ApiResponse(responseCode = "400", description = "Invalid request data or business rule violation"),
        @ApiResponse(responseCode = "500", description = "Internal server error")
    })
    public ResponseEntity<?> transfer(@Valid @RequestBody TransferRequest request) {
        try {
            TransactionResult result = transferService.performTransfer(request);
            if ("FAILED".equals(result.getStatus())) {
                return ResponseEntity.badRequest().body(result);
            }
            return ResponseEntity.ok(result);
        } catch (Exception e) {
            log.error("Transfer failed unexpectedly", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(ErrorResponse.builder()
                    .status(500)
                    .error("Internal Server Error")
                    .message(e.getMessage())
                    .timestamp(LocalDateTime.now())
                    .build());
        }
    }

    @PostMapping("/transfers/reverse")
    @Operation(summary = "Reverse a posted transaction",
               description = "Creates offsetting ledger entries and marks the original transaction as REVERSED")
    @ApiResponses(value = {
        @ApiResponse(responseCode = "200", description = "Reversal completed or duplicate request returned"),
        @ApiResponse(responseCode = "400", description = "Invalid request or original transaction not in POSTED status"),
        @ApiResponse(responseCode = "500", description = "Internal server error")
    })
    public ResponseEntity<?> reverseTransaction(@Valid @RequestBody ReverseTransactionRequest request) {
        try {
            TransactionResult result = transferService.reverseTransaction(request);
            if ("FAILED".equals(result.getStatus())) {
                return ResponseEntity.badRequest().body(result);
            }
            return ResponseEntity.ok(result);
        } catch (Exception e) {
            log.error("Reversal failed unexpectedly", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(ErrorResponse.builder()
                    .status(500)
                    .error("Internal Server Error")
                    .message(e.getMessage())
                    .timestamp(LocalDateTime.now())
                    .build());
        }
    }
}
