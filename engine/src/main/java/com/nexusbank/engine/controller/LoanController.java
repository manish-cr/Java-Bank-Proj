package com.nexusbank.engine.controller;

import com.nexusbank.engine.dto.request.LoanPaymentRequest;
import com.nexusbank.engine.dto.response.ErrorResponse;
import com.nexusbank.engine.dto.response.LoanPaymentResponse;
import com.nexusbank.engine.service.LoanService;
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
@RequestMapping("/products/loans")
@RequiredArgsConstructor
@Tag(name = "Loan Payments", description = "Loan payment processing")
public class LoanController {

    private final LoanService loanService;

    @PostMapping("/{loanAccountId}/payments")
    @Operation(summary = "Make a loan payment")
    public ResponseEntity<?> makePayment(
            @PathVariable String loanAccountId,
            @Valid @RequestBody LoanPaymentRequest request) {
        try {
            LoanPaymentResponse result = loanService.makePayment(request);
            if ("FAILED".equals(result.getStatus())) {
                return ResponseEntity.badRequest().body(result);
            }
            return ResponseEntity.ok(result);
        } catch (Exception e) {
            log.error("Loan payment failed", e);
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
