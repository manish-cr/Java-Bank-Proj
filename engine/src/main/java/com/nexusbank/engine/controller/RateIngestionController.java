package com.nexusbank.engine.controller;

import com.nexusbank.engine.service.RateIngestionService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/admin/rates")
@RequiredArgsConstructor
@Tag(name = "Rate Ingestion", description = "External rate API integration")
public class RateIngestionController {

    private final RateIngestionService rateIngestionService;

    @PostMapping("/ingest")
    @Operation(summary = "Ingest latest rates from external APIs (FRED, ECB, CurrencyAPI)")
    public ResponseEntity<Map<String, Object>> ingestRates() {
        return ResponseEntity.ok(rateIngestionService.ingestAllRates());
    }
}
