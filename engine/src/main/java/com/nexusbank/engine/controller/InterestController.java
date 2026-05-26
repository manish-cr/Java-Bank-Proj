package com.nexusbank.engine.controller;

import com.nexusbank.engine.dto.response.TransactionResult;
import com.nexusbank.engine.service.InterestAccrualService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/admin/jobs/interest")
@RequiredArgsConstructor
@Tag(name = "Interest Jobs", description = "Manual triggers for interest accrual and compounding")
public class InterestController {

    private final InterestAccrualService interestAccrualService;

    @PostMapping("/daily")
    @Operation(summary = "Trigger daily interest accrual for all savings accounts")
    public ResponseEntity<Map<String, Object>> triggerDailyAccrual() {
        return ResponseEntity.ok(interestAccrualService.accrueDailyInterestForAllAccounts());
    }

    @PostMapping("/daily/{accountId}")
    @Operation(summary = "Trigger daily interest accrual for a single account")
    public ResponseEntity<Map<String, Object>> triggerDailyAccrualForAccount(@PathVariable UUID accountId) {
        try {
            var future = interestAccrualService.processAccount(accountId);
            return ResponseEntity.ok(future.join());
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of(
                "accountId", accountId,
                "success", false,
                "message", e.getMessage()
            ));
        }
    }

    @PostMapping("/compound")
    @Operation(summary = "Trigger interest compounding for all due accounts")
    public ResponseEntity<Map<String, Object>> triggerCompounding() {
        return ResponseEntity.ok(interestAccrualService.compoundAllDueAccounts());
    }

    @PostMapping("/compound/{accountId}")
    @Operation(summary = "Trigger interest compounding for a single account")
    public ResponseEntity<TransactionResult> triggerCompoundingForAccount(@PathVariable UUID accountId) {
        return ResponseEntity.ok(interestAccrualService.compoundInterest(accountId));
    }
}
