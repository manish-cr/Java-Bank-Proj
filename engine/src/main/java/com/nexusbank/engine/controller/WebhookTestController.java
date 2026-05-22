package com.nexusbank.engine.controller;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.List;
import java.util.Map;
import java.util.HashMap;

@Slf4j
@RestController
@RequestMapping("/webhook")
@Tag(name = "Webhook Test Receiver", description = "Receives webhook events for testing")
public class WebhookTestController {

    public static final List<Map<String, Object>> receivedEvents = new CopyOnWriteArrayList<>();

    @PostMapping
    @Operation(summary = "Receive webhook event (mock endpoint)")
    public ResponseEntity<Map<String, String>> receiveWebhook(
            @RequestBody String payload,
            @RequestHeader("X-Event-Type") String eventType,
            @RequestHeader("X-Event-Id") String eventId,
            HttpServletRequest request) {

        Map<String, Object> event = new HashMap<>();
        event.put("receivedAt", LocalDateTime.now().toString());
        event.put("eventType", eventType);
        event.put("eventId", eventId);
        event.put("payload", payload);
        event.put("remoteAddr", request.getRemoteAddr());

        receivedEvents.add(event);
        log.info("Webhook received: type={}, eventId={}", eventType, eventId);
        log.debug("Payload: {}", payload);

        return ResponseEntity.ok(Map.of("status", "received", "eventId", eventId));
    }

    @GetMapping("/received")
    @Operation(summary = "View all received webhook events")
    public ResponseEntity<List<Map<String, Object>>> getReceivedEvents() {
        return ResponseEntity.ok(receivedEvents);
    }

    @DeleteMapping("/received")
    @Operation(summary = "Clear received webhook events")
    public ResponseEntity<Map<String, String>> clearEvents() {
        receivedEvents.clear();
        return ResponseEntity.ok(Map.of("status", "cleared"));
    }
}
