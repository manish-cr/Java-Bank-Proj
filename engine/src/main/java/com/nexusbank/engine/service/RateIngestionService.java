package com.nexusbank.engine.service;

import com.nexusbank.engine.config.RateApiConfig;
import com.nexusbank.engine.entity.InterestRateSchedule;
import com.nexusbank.engine.repository.InterestRateScheduleRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.reactive.function.client.WebClient;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.util.*;

@Slf4j
@Service
@RequiredArgsConstructor
public class RateIngestionService {

    private final RateApiConfig.RateApiProperties props;
    private final WebClient fredWebClient;
    private final WebClient ecbWebClient;
    private final WebClient currencyApiWebClient;
    private final InterestRateScheduleRepository rateScheduleRepo;
    private final RateService rateService;
    private final ObjectMapper objectMapper = new ObjectMapper();

    @Scheduled(cron = "${app.rates.ingestion-cron:0 0 6 * * *}")
    @Transactional
    public Map<String, Object> ingestAllRates() {
        Map<String, Object> result = new LinkedHashMap<>();
        List<String> updated = new ArrayList<>();
        List<String> errors = new ArrayList<>();
        LocalDate effectiveDate = LocalDate.now().plusDays(1);

        // Ingest US rates
        try { ingestFredRate("SOFR", "SOFR", effectiveDate); updated.add("SOFR"); }
        catch (Exception e) { errors.add("SOFR: " + e.getMessage()); }

        try { ingestFredRate("FEDFUNDS", "FED_FUNDS", effectiveDate); updated.add("FED_FUNDS"); }
        catch (Exception e) { errors.add("FED_FUNDS: " + e.getMessage()); }

        // Ingest ECB rates
        try { ingestEcbRate("EST.B.EU000A2X2A4.WT", "ESTR", "EUR", effectiveDate); updated.add("ESTR"); }
        catch (Exception e) { errors.add("ESTR: " + e.getMessage()); }

        // Ingest forex rates
        try { ingestForexRates(effectiveDate); updated.add("FOREX_RATES"); }
        catch (Exception e) { errors.add("FOREX: " + e.getMessage()); }

        // Propagate base rate changes to product rates
        if (!updated.isEmpty()) {
            try {
                Map<String, Object> propagation = rateService.propagateRates();
                result.put("propagation", propagation);
            } catch (Exception e) {
                errors.add("Propagation: " + e.getMessage());
            }
        }

        result.put("updated", updated);
        result.put("errors", errors);
        result.put("effectiveDate", effectiveDate);
        result.put("timestamp", LocalDate.now());
        return result;
    }

    private void ingestFredRate(String seriesId, String rateCode, LocalDate effectiveDate) {
        if (props.getFred().getApiKey() == null || props.getFred().getApiKey().isEmpty()) {
            log.info("FRED API key not configured. Using existing rates for {}", rateCode);
            return;
        }

        try {
            String response = fredWebClient.get()
                .uri(uriBuilder -> uriBuilder
                    .queryParam("series_id", seriesId)
                    .queryParam("api_key", props.getFred().getApiKey())
                    .queryParam("file_type", "json")
                    .queryParam("sort_order", "desc")
                    .queryParam("limit", "1")
                    .build())
                .retrieve()
                .bodyToMono(String.class)
                .block();

            JsonNode root = objectMapper.readTree(response);
            JsonNode observations = root.path("observations");
            if (observations.isArray() && !observations.isEmpty()) {
                BigDecimal rate = new BigDecimal(observations.get(0).path("value").asText());
                upsertRate(rateCode, rate, "USD", "BENCHMARK", effectiveDate,
                    "FRED series " + seriesId);
                log.info("FRED rate ingested: {} = {}%", rateCode, rate);
            }
        } catch (Exception e) {
            log.error("Failed to ingest FRED rate {}: {}", rateCode, e.getMessage());
            throw new RuntimeException("FRED ingestion failed for " + rateCode, e);
        }
    }

    private void ingestEcbRate(String dataflow, String rateCode, String currency, LocalDate effectiveDate) {
        try {
            String response = ecbWebClient.get()
                .uri(uriBuilder -> uriBuilder
                    .path("/{dataflow}/M..B.A2A.RA.0000.SMQ.N")
                    .queryParam("format", "jsondata")
                    .queryParam("lastNObservations", "1")
                    .build(dataflow))
                .retrieve()
                .bodyToMono(String.class)
                .block();

            // ECB response parsing — simplified
            JsonNode root = objectMapper.readTree(response);
            JsonNode dataSets = root.path("dataSets");
            if (dataSets.isArray() && !dataSets.isEmpty()) {
                JsonNode series = dataSets.get(0).path("series").path("0:0:0:0:0:0:0").path("observations");
                if (series.isArray() && !series.isEmpty()) {
                    BigDecimal rate = new BigDecimal(series.get(series.size() - 1).get(0).asText());
                    rate = rate.divide(BigDecimal.valueOf(100), 4, RoundingMode.HALF_UP);
                    upsertRate(rateCode, rate, currency, "BENCHMARK", effectiveDate,
                        "ECB dataflow " + dataflow);
                    log.info("ECB rate ingested: {} = {}%", rateCode, rate);
                }
            }
        } catch (Exception e) {
            log.error("Failed to ingest ECB rate {}: {}", rateCode, e.getMessage());
            throw new RuntimeException("ECB ingestion failed for " + rateCode, e);
        }
    }

    private void ingestForexRates(LocalDate effectiveDate) {
        if (props.getCurrencyApi().getApiKey() == null || props.getCurrencyApi().getApiKey().isEmpty()) {
            log.info("CurrencyAPI key not configured. Skipping forex rates.");
            return;
        }

        try {
            String response = currencyApiWebClient.get()
                .uri(uriBuilder -> uriBuilder
                    .queryParam("base_currency", "USD")
                    .build())
                .retrieve()
                .bodyToMono(String.class)
                .block();

            JsonNode root = objectMapper.readTree(response);
            JsonNode data = root.path("data");

            String[] pairs = {"EUR", "GBP", "JPY", "CHF", "CNY"};
            for (String currency : pairs) {
                JsonNode pairData = data.path(currency);
                if (!pairData.isMissingNode()) {
                    BigDecimal rate = new BigDecimal(pairData.path("value").asText());
                    String rateCode = "FOREX_" + currency + "_USD";
                    upsertRate(rateCode, rate, "USD", "FOREX", effectiveDate,
                        "CurrencyAPI " + currency + "/USD");
                    log.info("Forex rate ingested: {} = {}", rateCode, rate);
                }
            }
        } catch (Exception e) {
            log.error("Failed to ingest forex rates: {}", e.getMessage());
            throw new RuntimeException("Forex ingestion failed", e);
        }
    }

    private void upsertRate(String rateCode, BigDecimal rateValue, String currencyCode,
                            String rateCategory, LocalDate effectiveDate, String description) {
        // Check if current rate is different
        InterestRateSchedule current = rateScheduleRepo
            .findCurrentRate(rateCode, currencyCode, LocalDate.now())
            .orElse(null);

        if (current != null &&
            current.getRateValue().setScale(4, RoundingMode.HALF_UP)
                .compareTo(rateValue.setScale(4, RoundingMode.HALF_UP)) == 0) {
            log.debug("Rate unchanged: {} = {}%", rateCode, rateValue);
            return;
        }

        // Close previous rate
        if (current != null) {
            current.setEffectiveUntil(LocalDate.now());
            rateScheduleRepo.save(current);
        }

        // Insert new rate
        InterestRateSchedule newRate = InterestRateSchedule.builder()
            .rateId(UUID.randomUUID())
            .rateCode(rateCode)
            .rateValue(rateValue.setScale(4, RoundingMode.HALF_UP))
            .currencyCode(currencyCode)
            .rateCategory(rateCategory)
            .effectiveFrom(effectiveDate)
            .isPromotional(false)
            .description(description)
            .build();

        rateScheduleRepo.save(newRate);

        // Check for significant change (>25 basis points)
        if (current != null) {
            BigDecimal change = rateValue.subtract(current.getRateValue()).abs();
            if (change.compareTo(new BigDecimal("0.2500")) > 0) {
                log.warn("SIGNIFICANT RATE CHANGE: {} moved from {}% to {}% (change: {} bps)",
                    rateCode, current.getRateValue(), rateValue,
                    change.multiply(BigDecimal.valueOf(100)));
            }
        }

        log.info("Rate updated: {} = {}% (effective {})", rateCode, rateValue, effectiveDate);
    }
}
