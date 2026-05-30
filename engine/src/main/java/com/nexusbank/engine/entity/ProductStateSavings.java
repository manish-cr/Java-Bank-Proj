package com.nexusbank.engine.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

@Entity
@Table(name = "product_state_savings")
@Getter @Setter
@NoArgsConstructor @AllArgsConstructor
@Builder
public class ProductStateSavings {

    @Id
    @Column(name = "account_id", columnDefinition = "UUID")
    private UUID accountId;

    @OneToOne(fetch = FetchType.LAZY)
    @MapsId
    @JoinColumn(name = "account_id")
    private Account account;

    @Column(name = "interest_rate", precision = 7, scale = 4, nullable = false)
    private BigDecimal interestRate;

    @Column(name = "compounding_frequency", length = 10, nullable = false)
    private String compoundingFrequency;

    @Column(name = "interest_accrued_pending", precision = 19, scale = 4, nullable = false)
    private BigDecimal interestAccruedPending;

    @Column(name = "interest_accrued_ytd", precision = 19, scale = 4, nullable = false)
    private BigDecimal interestAccruedYtd;

    @Column(name = "last_interest_date")
    private LocalDate lastInterestDate;

    @Column(name = "last_compound_date")
    private LocalDate lastCompoundDate;

    @Column(name = "rate_type", length = 20, nullable = false)
    private String rateType;

    @Column(name = "rate_code", length = 30)
    private String rateCode;
}
