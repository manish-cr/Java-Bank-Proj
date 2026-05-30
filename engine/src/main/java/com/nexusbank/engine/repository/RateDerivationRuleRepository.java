package com.nexusbank.engine.repository;

import com.nexusbank.engine.entity.RateDerivationRule;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

@Repository
public interface RateDerivationRuleRepository extends JpaRepository<RateDerivationRule, UUID> {

    @Query(value = """
        SELECT * FROM rate_derivation_rules
        WHERE effective_from <= :asOfDate
          AND (effective_until IS NULL OR effective_until > :asOfDate)
        ORDER BY product_rate_code
        """, nativeQuery = true)
    List<RateDerivationRule> findAllActive(@Param("asOfDate") LocalDate asOfDate);

    @Query(value = """
        SELECT * FROM rate_derivation_rules
        WHERE product_rate_code = :productRateCode
          AND currency_code = :currencyCode
          AND effective_from <= :asOfDate
          AND (effective_until IS NULL OR effective_until > :asOfDate)
        LIMIT 1
        """, nativeQuery = true)
    RateDerivationRule findActiveRule(
        @Param("productRateCode") String productRateCode,
        @Param("currencyCode") String currencyCode,
        @Param("asOfDate") LocalDate asOfDate);
}
