package com.nexusbank.engine.controller;

import com.nexusbank.engine.dto.response.TransactionResult;
import com.nexusbank.engine.service.FeeService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/admin/jobs/fees")
@RequiredArgsConstructor
@Tag(name = "Fee Jobs", description = "Manual triggers for monthly fees and late fees")
public class FeeController {

    private final FeeService feeService;

    @PostMapping("/monthly")
    @Operation(summary = "Charge monthly maintenance fees for all checking accounts")
    public ResponseEntity<Map<String, Object>> chargeMonthlyFees() {
        return ResponseEntity.ok(feeService.chargeAllMonthlyFees());
    }

    @PostMapping("/monthly/{accountId}")
    @Operation(summary = "Charge monthly fee for a single checking account")
    public ResponseEntity<TransactionResult> chargeMonthlyFee(@PathVariable UUID accountId) {
        return ResponseEntity.ok(feeService.chargeMonthlyFee(accountId));
    }

    @PostMapping("/late/{loanAccountId}")
    @Operation(summary = "Charge late payment fee for a loan account")
    public ResponseEntity<TransactionResult> chargeLateFee(@PathVariable UUID loanAccountId) {
        return ResponseEntity.ok(feeService.chargeLateFee(loanAccountId));
    }
}
