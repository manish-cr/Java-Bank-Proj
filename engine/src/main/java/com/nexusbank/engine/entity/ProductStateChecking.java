package com.nexusbank.engine.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

@Entity
@Table(name = "product_state_checking")
@Getter @Setter
@NoArgsConstructor @AllArgsConstructor
@Builder
public class ProductStateChecking {

    @Id
    @Column(name = "account_id", columnDefinition = "UUID")
    private UUID accountId;

    @OneToOne(fetch = FetchType.LAZY)
    @MapsId
    @JoinColumn(name = "account_id")
    private Account account;

    @Column(name = "monthly_fee", precision = 19, scale = 4, nullable = false)
    private BigDecimal monthlyFee;

    @Column(name = "overdraft_limit", precision = 19, scale = 4, nullable = false)
    private BigDecimal overdraftLimit;

    @Column(name = "last_fee_date")
    private LocalDate lastFeeDate;
}
