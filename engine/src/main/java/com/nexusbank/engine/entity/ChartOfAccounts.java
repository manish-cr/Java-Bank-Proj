package com.nexusbank.engine.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

@Entity
@Table(name = "chart_of_accounts")
@Getter @Setter
@NoArgsConstructor @AllArgsConstructor
@Builder
public class ChartOfAccounts {

    @Id
    @Column(name = "gl_account_code", length = 10)
    private String glAccountCode;

    @Column(name = "account_name", length = 100, nullable = false)
    private String accountName;

    @Column(name = "gl_type", length = 20, nullable = false)
    private String glType;

    @Column(name = "is_customer_facing", nullable = false)
    private Boolean isCustomerFacing;

    @Column(name = "created_at", nullable = false)
    private LocalDateTime createdAt;
}
