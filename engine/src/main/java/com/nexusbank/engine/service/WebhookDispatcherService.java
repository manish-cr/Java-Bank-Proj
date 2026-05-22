package com.nexusbank.engine.service;

import com.nexusbank.engine.config.WebhookConfig;
import com.nexusbank.engine.entity.OutboxEvent;
import com.nexusbank.engine.repository.OutboxEventRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.reactive.function.client.WebClient;
import reactor.core.publisher.Mono;

import java.time.Duration;
import java.time.LocalDateTime;
import java.util.List;

@Slf4j
@Service
@RequiredArgsConstructor
public class WebhookDispatcherService {

    private final OutboxEventRepository outboxEventRepository;
    private final WebClient webClient;
    private final WebhookConfig.WebhookProperties props;

    @Scheduled(fixedDelay = 5000)
    @Transactional
    public void dispatchPendingEvents() {
        List<OutboxEvent> pendingEvents = outboxEventRepository
            .findByStatusOrderByCreatedAtAsc("PENDING");

        if (pendingEvents.isEmpty()) {
            return;
        }

        log.debug("Found {} pending webhook events to dispatch", pendingEvents.size());

        for (OutboxEvent event : pendingEvents) {
            if (event.getRetryCount() >= props.getMaxRetries()) {
                markFailed(event, "Max retries (" + props.getMaxRetries() + ") exceeded");
                continue;
            }

            dispatchEvent(event);
        }
    }

    private void dispatchEvent(OutboxEvent event) {
        log.info("Dispatching webhook: eventId={}, type={}", event.getEventId(), event.getEventType());

        try {
            String response = webClient.post()
                .uri(props.getSubscriberUrl())
                .header("Content-Type", "application/json")
                .header("X-Event-Type", event.getEventType())
                .header("X-Event-Id", event.getEventId().toString())
                .bodyValue(event.getPayloadJson())
                .retrieve()
                .onStatus(status -> status.isError(), clientResponse ->
                    Mono.error(new RuntimeException("Webhook failed with status: " + clientResponse.statusCode())))
                .bodyToMono(String.class)
                .timeout(Duration.ofMillis(props.getReadTimeoutMs()))
                .block();

            markPublished(event, response);
        } catch (Exception e) {
            log.warn("Webhook delivery failed for event {}: {}", event.getEventId(), e.getMessage());
            markRetry(event, e.getMessage());
        }
    }

    private void markPublished(OutboxEvent event, String response) {
        event.setStatus("PUBLISHED");
        event.setUpdatedAt(LocalDateTime.now());
        outboxEventRepository.save(event);
        log.info("Webhook published successfully: eventId={}", event.getEventId());
    }

    private void markRetry(OutboxEvent event, String error) {
        event.setRetryCount(event.getRetryCount() + 1);
        event.setLastError(error);
        event.setUpdatedAt(LocalDateTime.now());
        outboxEventRepository.save(event);
        log.info("Webhook scheduled for retry: eventId={}, attempt={}/{}",
            event.getEventId(), event.getRetryCount(), props.getMaxRetries());
    }

    private void markFailed(OutboxEvent event, String reason) {
        event.setStatus("FAILED");
        event.setLastError(reason);
        event.setUpdatedAt(LocalDateTime.now());
        outboxEventRepository.save(event);
        log.error("Webhook permanently failed: eventId={}, reason={}", event.getEventId(), reason);
    }
}
