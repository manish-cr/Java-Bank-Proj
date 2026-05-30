package com.nexusbank.engine.controller;

import com.nexusbank.engine.entity.InterestRateSchedule;
import com.nexusbank.engine.service.RateService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/admin/rates")
@RequiredArgsConstructor
@Tag(name = "Rate Management", description = "Interest rate catalog and propagation")
public class RateController {

    private final RateService rateService;

    @GetMapping
    @Operation(summary = "Get all current rates")
    public ResponseEntity<Map<String, Object>> getAllRates() {
        return ResponseEntity.ok(rateService.getAllCurrentRates());
    }

    @GetMapping("/{rateCode}")
    @Operation(summary = "Get current rate for a specific rate code")
    public ResponseEntity<Map<String, Object>> getRate(
            @PathVariable String rateCode,
            @RequestParam(defaultValue = "USD") String currency) {
        BigDecimal rate = rateService.getCurrentRate(rateCode, currency);
        return ResponseEntity.ok(Map.of(
            "rateCode", rateCode,
            "currencyCode", currency,
            "rateValue", rate
        ));
    }

    @GetMapping("/tiers/{rateCode}")
    @Operation(summary = "Get tiered rate for a balance")
    public ResponseEntity<Map<String, Object>> getTieredRate(
            @PathVariable String rateCode,
            @RequestParam BigDecimal balance,
            @RequestParam(defaultValue = "USD") String currency) {
        BigDecimal rate = rateService.getRateForTier(rateCode, balance, currency);
        List<InterestRateSchedule> tiers = rateService.getTieredRates(rateCode, currency);
        return ResponseEntity.ok(Map.of(
            "rateCode", rateCode,
            "balance", balance,
            "applicableRate", rate,
            "allTiers", tiers
        ));
    }

    @PostMapping("/propagate")
    @Operation(summary = "Propagate base rate changes to all product rates")
    public ResponseEntity<Map<String, Object>> propagateRates() {
        return ResponseEntity.ok(rateService.propagateRates());
    }
}
