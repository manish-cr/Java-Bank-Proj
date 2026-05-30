package com.nexusbank.engine.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "interest_rate_schedule")
@Getter @Setter
@NoArgsConstructor @AllArgsConstructor
@Builder
public class InterestRateSchedule {

    @Id
    @Column(name = "rate_id", columnDefinition = "UUID")
    private UUID rateId;

    @Column(name = "rate_code", length = 30, nullable = false)
    private String rateCode;

    @Column(name = "rate_value", precision = 7, scale = 4, nullable = false)
    private BigDecimal rateValue;

    @Column(name = "currency_code", length = 3, nullable = false)
    private String currencyCode;

    @Column(name = "rate_category", length = 20, nullable = false)
    private String rateCategory;

    @Column(name = "effective_from", nullable = false)
    private LocalDate effectiveFrom;

    @Column(name = "effective_until")
    private LocalDate effectiveUntil;

    @Column(name = "tier_min_balance", precision = 19, scale = 4)
    private BigDecimal tierMinBalance;

    @Column(name = "tier_max_balance", precision = 19, scale = 4)
    private BigDecimal tierMaxBalance;

    @Column(name = "tier_sequence")
    private Integer tierSequence;

    @Column(name = "loan_term_min_months")
    private Integer loanTermMinMonths;

    @Column(name = "loan_term_max_months")
    private Integer loanTermMaxMonths;

    @Column(name = "collateral_required", length = 20)
    private String collateralRequired;

    @Column(name = "is_promotional", nullable = false)
    private Boolean isPromotional;

    @Column(name = "promo_description", length = 200)
    private String promoDescription;

    @Column(length = 200)
    private String description;

    @Column(name = "created_at", nullable = false)
    private LocalDateTime createdAt;
}
