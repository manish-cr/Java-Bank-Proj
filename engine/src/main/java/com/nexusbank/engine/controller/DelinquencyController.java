package com.nexusbank.engine.controller;

import com.nexusbank.engine.service.DelinquencyService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/admin/jobs/loans")
@RequiredArgsConstructor
@Tag(name = "Loan Delinquency", description = "Delinquency checks and collections")
public class DelinquencyController {

    private final DelinquencyService delinquencyService;

    @PostMapping("/delinquency")
    @Operation(summary = "Run delinquency check on all active loans")
    public ResponseEntity<Map<String, Object>> checkDelinquency() {
        return ResponseEntity.ok(delinquencyService.checkDelinquency());
    }
}
