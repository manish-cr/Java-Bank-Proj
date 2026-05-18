package com.nexusbank.engine.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;

@Entity
@Table(name = "fee_schedule")
@Getter @Setter
@NoArgsConstructor @AllArgsConstructor
@Builder
public class FeeSchedule {

    @Id
    @Column(name = "fee_code", length = 30)
    private String feeCode;

    @Column(name = "fee_name", length = 100, nullable = false)
    private String feeName;

    @Column(precision = 19, scale = 4, nullable = false)
    private BigDecimal amount;

    @Column(name = "currency_code", columnDefinition = "CHAR(3)", length = 3, nullable = false)
    private String currencyCode;

    @Column(name = "applies_to_account_type", length = 20, nullable = false)
    private String appliesToAccountType;

    @Column(name = "is_active", nullable = false)
    private Boolean isActive;
}
