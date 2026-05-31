package com.nexusbank.engine.service;

import jakarta.persistence.EntityManager;
import jakarta.persistence.StoredProcedureQuery;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.*;

@Slf4j
@Service
@RequiredArgsConstructor
public class DelinquencyService {

    private final EntityManager entityManager;

    @Transactional
    public Map<String, Object> checkDelinquency() {
        log.info("Starting loan delinquency check...");

        StoredProcedureQuery query = entityManager
            .createStoredProcedureQuery("sp_check_loan_delinquency");

        @SuppressWarnings("unchecked")
        List<Object[]> results = query.getResultList();

        List<Map<String, Object>> delinquentLoans = new ArrayList<>();
        int totalDelinquent = 0;
        int lateFeesCharged = 0;

        for (Object[] row : results) {
            Map<String, Object> entry = new HashMap<>();
            entry.put("accountId", row[0]);
            entry.put("accountNumber", row[1]);
            entry.put("daysPastDue", row[2]);
            entry.put("lateFeeCharged", row[3]);
            entry.put("status", row[4]);
            entry.put("message", row[5]);

            if ("DELINQUENT".equals(row[4])) {
                totalDelinquent++;
                if (Boolean.TRUE.equals(row[3])) {
                    lateFeesCharged++;
                }
            }

            delinquentLoans.add(entry);
        }

        Map<String, Object> summary = new HashMap<>();
        summary.put("totalDelinquent", totalDelinquent);
        summary.put("lateFeesCharged", lateFeesCharged);
        summary.put("delinquentLoans", delinquentLoans);
        summary.put("timestamp", LocalDateTime.now());

        log.info("Delinquency check complete: {} delinquent, {} late fees charged",
            totalDelinquent, lateFeesCharged);

        return summary;
    }
}
