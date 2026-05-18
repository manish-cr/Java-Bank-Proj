package com.nexusbank.engine.dto.request;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ReverseTransactionRequest {

    @NotNull(message = "Idempotency key is required")
    private UUID idempotencyKey;

    @NotNull(message = "Original transaction ID is required")
    private UUID originalTransactionId;

    @Size(max = 500)
    private String reason;
}
