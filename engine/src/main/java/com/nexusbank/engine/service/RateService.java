package com.nexusbank.engine.service;

import com.nexusbank.engine.entity.InterestRateSchedule;
import com.nexusbank.engine.entity.RateDerivationRule;
import com.nexusbank.engine.repository.InterestRateScheduleRepository;
import com.nexusbank.engine.repository.RateDerivationRuleRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.util.*;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class RateService {

    private final InterestRateScheduleRepository rateScheduleRepo;
    private final RateDerivationRuleRepository derivationRuleRepo;

    @Transactional(readOnly = true)
    public BigDecimal getCurrentRate(String rateCode, String currencyCode) {
        return rateScheduleRepo.findCurrentRate(rateCode, currencyCode, LocalDate.now())
            .map(InterestRateSchedule::getRateValue)
            .orElseThrow(() -> new RuntimeException("Rate not found: " + rateCode + " for " + currencyCode));
    }

    @Transactional(readOnly = true)
    public BigDecimal getRateForTier(String rateCode, BigDecimal balance, String currencyCode) {
        return rateScheduleRepo.findRateForTier(rateCode, currencyCode, balance, LocalDate.now())
            .map(InterestRateSchedule::getRateValue)
            .orElse(null);
    }

    @Transactional(readOnly = true)
    public List<InterestRateSchedule> getTieredRates(String rateCode, String currencyCode) {
        return rateScheduleRepo.findTieredRates(rateCode, currencyCode, LocalDate.now());
    }

    @Transactional(readOnly = true)
    public Map<String, Object> getAllCurrentRates() {
        List<String> rateCodes = rateScheduleRepo.findActiveRateCodes("USD", LocalDate.now());
        Map<String, Object> rates = new LinkedHashMap<>();

        for (String code : rateCodes) {
            InterestRateSchedule rate = rateScheduleRepo
                .findCurrentRate(code, "USD", LocalDate.now())
                .orElse(null);
            if (rate != null) {
                Map<String, Object> rateInfo = new LinkedHashMap<>();
                rateInfo.put("rateCode", rate.getRateCode());
                rateInfo.put("rateValue", rate.getRateValue());
                rateInfo.put("category", rate.getRateCategory());
                rateInfo.put("effectiveFrom", rate.getEffectiveFrom());
                rateInfo.put("description", rate.getDescription());
                rates.put(code, rateInfo);
            }
        }
        return rates;
    }

    @Transactional
    public Map<String, Object> propagateRates() {
        List<RateDerivationRule> rules = derivationRuleRepo.findAllActive(LocalDate.now());
        int updated = 0;
        int unchanged = 0;
        int errors = 0;

        for (RateDerivationRule rule : rules) {
            try {
                BigDecimal baseRate = rateScheduleRepo
                    .findCurrentRate(rule.getBaseRateCode(), rule.getCurrencyCode(), LocalDate.now())
                    .orElseThrow(() -> new RuntimeException("Base rate not found: " + rule.getBaseRateCode()))
                    .getRateValue();

                BigDecimal newRate;
                switch (rule.getFormulaType()) {
                    case "SPREAD":
                        newRate = baseRate.add(rule.getSpreadValue());
                        break;
                    case "MULTIPLIER":
                        newRate = baseRate.multiply(rule.getMultiplier());
                        break;
                    case "FIXED":
                        newRate = rule.getSpreadValue();
                        break;
                    default:
                        continue;
                }

                if (rule.getFloorRate() != null) {
                    newRate = newRate.max(rule.getFloorRate());
                }
                if (rule.getCeilingRate() != null) {
                    newRate = newRate.min(rule.getCeilingRate());
                }

                InterestRateSchedule currentProductRate = rateScheduleRepo
                    .findCurrentRate(rule.getProductRateCode(), rule.getCurrencyCode(), LocalDate.now())
                    .orElse(null);

                if (currentProductRate != null &&
                    currentProductRate.getRateValue().setScale(4, RoundingMode.HALF_UP)
                        .compareTo(newRate.setScale(4, RoundingMode.HALF_UP)) == 0) {
                    unchanged++;
                    continue;
                }

                if (currentProductRate != null) {
                    currentProductRate.setEffectiveUntil(LocalDate.now());
                    rateScheduleRepo.save(currentProductRate);
                }

                InterestRateSchedule newRateEntity = InterestRateSchedule.builder()
                    .rateId(UUID.randomUUID())
                    .rateCode(rule.getProductRateCode())
                    .rateValue(newRate.setScale(4, RoundingMode.HALF_UP))
                    .currencyCode(rule.getCurrencyCode())
                    .rateCategory("PRODUCT")
                    .effectiveFrom(LocalDate.now().plusDays(1))
                    .isPromotional(false)
                    .description(rule.getDescription())
                    .build();

                rateScheduleRepo.save(newRateEntity);
                updated++;
                log.info("Rate propagated: {} = {} ({})", rule.getProductRateCode(), newRate, rule.getDescription());

            } catch (Exception e) {
                log.error("Failed to propagate rate for {}: {}", rule.getProductRateCode(), e.getMessage());
                errors++;
            }
        }

        Map<String, Object> result = new HashMap<>();
        result.put("totalRules", rules.size());
        result.put("updated", updated);
        result.put("unchanged", unchanged);
        result.put("errors", errors);
        result.put("timestamp", LocalDate.now());
        return result;
    }
}
