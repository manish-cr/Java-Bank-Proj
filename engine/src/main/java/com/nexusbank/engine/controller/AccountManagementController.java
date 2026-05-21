package com.nexusbank.engine.controller;

import com.nexusbank.engine.dto.request.CreateAccountRequest;
import com.nexusbank.engine.dto.response.AccountDetailResponse;
import com.nexusbank.engine.dto.response.CreateAccountResponse;
import com.nexusbank.engine.dto.response.ErrorResponse;
import com.nexusbank.engine.service.AccountManagementService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.UUID;

@Slf4j
@RestController
@RequestMapping("/accounts")
@RequiredArgsConstructor
@Tag(name = "Account Management", description = "Account creation and detail retrieval")
public class AccountManagementController {

    private final AccountManagementService accountManagementService;

    @PostMapping
    @Operation(summary = "Create a new account")
    public ResponseEntity<?> createAccount(@Valid @RequestBody CreateAccountRequest request) {
        try {
            CreateAccountResponse result = accountManagementService.createAccount(request);
            if ("FAILED".equals(result.getStatus())) {
                return ResponseEntity.badRequest().body(result);
            }
            return ResponseEntity.status(HttpStatus.CREATED).body(result);
        } catch (Exception e) {
            log.error("Account creation failed", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(ErrorResponse.builder().status(500).error("Internal Server Error")
                    .message(e.getMessage()).timestamp(LocalDateTime.now()).build());
        }
    }

    @GetMapping("/{accountId}")
    @Operation(summary = "Get full account details")
    public ResponseEntity<AccountDetailResponse> getAccountDetail(@PathVariable UUID accountId) {
        return ResponseEntity.ok(accountManagementService.getAccountDetail(accountId));
    }
}
