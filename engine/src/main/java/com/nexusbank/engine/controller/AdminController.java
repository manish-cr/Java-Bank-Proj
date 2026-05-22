package com.nexusbank.engine.controller;

import com.nexusbank.engine.entity.OutboxEvent;
import com.nexusbank.engine.repository.OutboxEventRepository;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/admin")
@RequiredArgsConstructor
@Tag(name = "Admin", description = "Administrative endpoints")
public class AdminController {

    private final OutboxEventRepository outboxEventRepository;

    @GetMapping("/outbox/pending")
    @Operation(summary = "View pending webhook events")
    public ResponseEntity<List<OutboxEvent>> getPendingEvents() {
        return ResponseEntity.ok(
            outboxEventRepository.findByStatusOrderByCreatedAtAsc("PENDING"));
    }

    @GetMapping("/outbox/failed")
    @Operation(summary = "View failed webhook events")
    public ResponseEntity<List<OutboxEvent>> getFailedEvents() {
        return ResponseEntity.ok(
            outboxEventRepository.findByStatusOrderByCreatedAtAsc("FAILED"));
    }

    @PostMapping("/outbox/{eventId}/retry")
    @Operation(summary = "Manually retry a failed webhook event")
    public ResponseEntity<Map<String, String>> retryEvent(@PathVariable UUID eventId) {
        var event = outboxEventRepository.findById(eventId)
            .orElseThrow(() -> new RuntimeException("Event not found"));
        event.setStatus("PENDING");
        event.setRetryCount(0);
        event.setLastError(null);
        outboxEventRepository.save(event);
        return ResponseEntity.ok(Map.of("status", "reset", "eventId", eventId.toString()));
    }
}
