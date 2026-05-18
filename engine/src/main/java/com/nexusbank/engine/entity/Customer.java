package com.nexusbank.engine.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Entity
@Table(name = "customer")
@Getter @Setter
@NoArgsConstructor @AllArgsConstructor
@Builder
public class Customer {

    @Id
    @Column(name = "customer_id", columnDefinition = "UUID")
    private UUID customerId;

    @Column(name = "persona_type", length = 20, nullable = false)
    private String personaType;

    @Column(name = "kyc_status", length = 20, nullable = false)
    private String kycStatus;

    @Column(name = "legal_name", length = 255, nullable = false)
    private String legalName;

    @Column(length = 255, nullable = false, unique = true)
    private String email;

    @Column(name = "created_at", nullable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

    @OneToMany(mappedBy = "customer", fetch = FetchType.LAZY)
    private List<Account> accounts = new ArrayList<>();
}
