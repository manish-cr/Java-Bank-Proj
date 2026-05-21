package com.nexusbank.engine.controller;

import com.nexusbank.engine.dto.request.DepositRequest;
import com.nexusbank.engine.dto.request.ReverseTransactionRequest;
import com.nexusbank.engine.dto.request.WithdrawalRequest;
import com.nexusbank.engine.dto.response.ErrorResponse;
import com.nexusbank.engine.dto.response.TransactionResult;
import com.nexusbank.engine.service.TransactionService;
import com.nexusbank.engine.service.TransferService;
import io.swagger.v3.oas.annotations.Operation;
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
@Tag(name = "Transactions", description = "Deposit, withdrawal, and reversal operations")
public class TransactionController {

    private final TransactionService transactionService;
    private final TransferService transferService;

    @PostMapping("/deposits")
    @Operation(summary = "Deposit money into an account")
    public ResponseEntity<?> deposit(@Valid @RequestBody DepositRequest request) {
        try {
            TransactionResult result = transactionService.performDeposit(request);
            if ("FAILED".equals(result.getStatus())) {
                return ResponseEntity.badRequest().body(result);
            }
            return ResponseEntity.ok(result);
        } catch (Exception e) {
            log.error("Deposit failed unexpectedly", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(ErrorResponse.builder().status(500).error("Internal Server Error")
                    .message(e.getMessage()).timestamp(LocalDateTime.now()).build());
        }
    }

    @PostMapping("/withdrawals")
    @Operation(summary = "Withdraw money from an account")
    public ResponseEntity<?> withdraw(@Valid @RequestBody WithdrawalRequest request) {
        try {
            TransactionResult result = transactionService.performWithdrawal(request);
            if ("FAILED".equals(result.getStatus())) {
                return ResponseEntity.badRequest().body(result);
            }
            return ResponseEntity.ok(result);
        } catch (Exception e) {
            log.error("Withdrawal failed unexpectedly", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(ErrorResponse.builder().status(500).error("Internal Server Error")
                    .message(e.getMessage()).timestamp(LocalDateTime.now()).build());
        }
    }

    @PostMapping("/reverse")
    @Operation(summary = "Reverse any posted transaction (transfer, deposit, or withdrawal)")
    public ResponseEntity<?> reverse(@Valid @RequestBody ReverseTransactionRequest request) {
        try {
            TransactionResult result = transferService.reverseTransaction(request);
            if ("FAILED".equals(result.getStatus())) {
                return ResponseEntity.badRequest().body(result);
            }
            return ResponseEntity.ok(result);
        } catch (Exception e) {
            log.error("Reversal failed unexpectedly", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(ErrorResponse.builder().status(500).error("Internal Server Error")
                    .message(e.getMessage()).timestamp(LocalDateTime.now()).build());
        }
    }
}
