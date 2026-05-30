package com.nexusbank.engine.repository;

import com.nexusbank.engine.entity.InterestRateSchedule;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface InterestRateScheduleRepository extends JpaRepository<InterestRateSchedule, UUID> {

    @Query(value = """
        SELECT * FROM interest_rate_schedule
        WHERE rate_code = :rateCode
          AND currency_code = :currencyCode
          AND effective_from <= :asOfDate
          AND (effective_until IS NULL OR effective_until > :asOfDate)
        ORDER BY effective_from DESC
        LIMIT 1
        """, nativeQuery = true)
    Optional<InterestRateSchedule> findCurrentRate(
        @Param("rateCode") String rateCode,
        @Param("currencyCode") String currencyCode,
        @Param("asOfDate") LocalDate asOfDate);

    @Query(value = """
        SELECT * FROM interest_rate_schedule
        WHERE rate_code = :rateCode
          AND currency_code = :currencyCode
          AND effective_from <= :asOfDate
          AND (effective_until IS NULL OR effective_until > :asOfDate)
          AND (tier_min_balance IS NULL OR tier_min_balance <= :balance)
          AND (tier_max_balance IS NULL OR tier_max_balance >= :balance)
        ORDER BY tier_sequence
        LIMIT 1
        """, nativeQuery = true)
    Optional<InterestRateSchedule> findRateForTier(
        @Param("rateCode") String rateCode,
        @Param("currencyCode") String currencyCode,
        @Param("balance") BigDecimal balance,
        @Param("asOfDate") LocalDate asOfDate);

    @Query(value = """
        SELECT * FROM interest_rate_schedule
        WHERE rate_code = :rateCode
          AND currency_code = :currencyCode
          AND effective_from <= :asOfDate
          AND (effective_until IS NULL OR effective_until > :asOfDate)
        ORDER BY tier_sequence
        """, nativeQuery = true)
    List<InterestRateSchedule> findTieredRates(
        @Param("rateCode") String rateCode,
        @Param("currencyCode") String currencyCode,
        @Param("asOfDate") LocalDate asOfDate);

    @Query(value = """
        SELECT DISTINCT rate_code FROM interest_rate_schedule
        WHERE currency_code = :currencyCode
          AND effective_from <= :asOfDate
          AND (effective_until IS NULL OR effective_until > :asOfDate)
        ORDER BY rate_code
        """, nativeQuery = true)
    List<String> findActiveRateCodes(
        @Param("currencyCode") String currencyCode,
        @Param("asOfDate") LocalDate asOfDate);
}
