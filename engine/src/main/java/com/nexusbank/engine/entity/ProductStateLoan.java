package com.nexusbank.engine.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

@Entity
@Table(name = "product_state_loan")
@Getter @Setter
@NoArgsConstructor @AllArgsConstructor
@Builder
public class ProductStateLoan {

    @Id
    @Column(name = "account_id", columnDefinition = "UUID")
    private UUID accountId;

    @OneToOne(fetch = FetchType.LAZY)
    @MapsId
    @JoinColumn(name = "account_id")
    private Account account;

    @Column(name = "original_principal", precision = 19, scale = 4, nullable = false)
    private BigDecimal originalPrincipal;

    @Column(name = "principal_outstanding", precision = 19, scale = 4, nullable = false)
    private BigDecimal principalOutstanding;

    @Column(name = "interest_rate", precision = 7, scale = 4, nullable = false)
    private BigDecimal interestRate;

    @Column(name = "loan_term_months", nullable = false)
    private Integer loanTermMonths;

    @Column(name = "monthly_payment", precision = 19, scale = 4, nullable = false)
    private BigDecimal monthlyPayment;

    @Column(name = "next_payment_date", nullable = false)
    private LocalDate nextPaymentDate;

    @Column(name = "days_past_due", nullable = false)
    private Integer daysPastDue;

    @Column(name = "total_interest_paid_ytd", precision = 19, scale = 4, nullable = false)
    private BigDecimal totalInterestPaidYtd;
}
