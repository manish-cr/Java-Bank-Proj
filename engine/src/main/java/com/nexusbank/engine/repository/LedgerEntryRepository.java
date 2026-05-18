package com.nexusbank.engine.repository;

import com.nexusbank.engine.entity.LedgerEntry;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface LedgerEntryRepository extends JpaRepository<LedgerEntry, UUID> {

    @Query(value = """
        SELECT le.balance_after FROM ledger_entry le
        WHERE le.account_id = :accountId
        ORDER BY le.entry_date DESC, le.created_at DESC
        LIMIT 1
        """, nativeQuery = true)
    Optional<BigDecimal> findCurrentBalance(@Param("accountId") UUID accountId);

    @Query(value = """
        SELECT le.balance_after FROM ledger_entry le
        WHERE le.account_id = :accountId
          AND le.entry_date <= :asOfDate
        ORDER BY le.entry_date DESC, le.created_at DESC
        LIMIT 1
        """, nativeQuery = true)
    Optional<BigDecimal> findBalanceAsOf(@Param("accountId") UUID accountId,
                                          @Param("asOfDate") LocalDate asOfDate);

    @Query(value = """
        SELECT le.* FROM ledger_entry le
        JOIN transaction t ON le.transaction_id = t.transaction_id
        WHERE le.account_id = :accountId
          AND le.entry_date BETWEEN :fromDate AND :toDate
        ORDER BY le.entry_date DESC, le.created_at DESC
        """, countQuery = """
        SELECT COUNT(*) FROM ledger_entry le
        WHERE le.account_id = :accountId
          AND le.entry_date BETWEEN :fromDate AND :toDate
        """, nativeQuery = true)
    Page<LedgerEntry> findTransactionHistory(
        @Param("accountId") UUID accountId,
        @Param("fromDate") LocalDate fromDate,
        @Param("toDate") LocalDate toDate,
        Pageable pageable
    );
}
