package com.nexusbank.engine.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "transaction")
@Getter @Setter
@NoArgsConstructor @AllArgsConstructor
@Builder
public class Transaction {

    @Id
    @Column(name = "transaction_id", columnDefinition = "UUID")
    private UUID transactionId;

    @Column(name = "idempotency_key", columnDefinition = "UUID", nullable = false, unique = true)
    private UUID idempotencyKey;

    @Column(name = "transaction_type", length = 30, nullable = false)
    private String transactionType;

    @Column(length = 20, nullable = false)
    private String status;

    @Column(name = "business_date", nullable = false)
    private LocalDate businessDate;

    @Column(length = 500)
    private String description;

    @Column(name = "created_at", nullable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;
}
