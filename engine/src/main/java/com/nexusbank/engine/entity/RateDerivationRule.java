package com.nexusbank.engine.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "rate_derivation_rules")
@Getter @Setter
@NoArgsConstructor @AllArgsConstructor
@Builder
public class RateDerivationRule {

    @Id
    @Column(name = "rule_id", columnDefinition = "UUID")
    private UUID ruleId;

    @Column(name = "product_rate_code", length = 30, nullable = false)
    private String productRateCode;

    @Column(name = "base_rate_code", length = 30, nullable = false)
    private String baseRateCode;

    @Column(name = "formula_type", length = 20, nullable = false)
    private String formulaType;

    @Column(name = "spread_value", precision = 7, scale = 4)
    private BigDecimal spreadValue;

    @Column(precision = 7, scale = 4)
    private BigDecimal multiplier;

    @Column(name = "floor_rate", precision = 7, scale = 4)
    private BigDecimal floorRate;

    @Column(name = "ceiling_rate", precision = 7, scale = 4)
    private BigDecimal ceilingRate;

    @Column(name = "currency_code", length = 3, nullable = false)
    private String currencyCode;

    @Column(name = "effective_from", nullable = false)
    private LocalDate effectiveFrom;

    @Column(name = "effective_until")
    private LocalDate effectiveUntil;

    @Column(length = 200)
    private String description;

    @Column(name = "created_at", nullable = false)
    private LocalDateTime createdAt;
}
