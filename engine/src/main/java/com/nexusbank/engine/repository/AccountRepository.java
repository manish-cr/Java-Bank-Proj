package com.nexusbank.engine.repository;

import com.nexusbank.engine.entity.Account;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface AccountRepository extends JpaRepository<Account, UUID> {

    Optional<Account> findByAccountNumber(String accountNumber);

    @Query(value = """
        SELECT a.* FROM account a
        WHERE a.customer_id = :customerId AND a.status = 'ACTIVE'
        """, nativeQuery = true)
    List<Account> findActiveByCustomerId(@Param("customerId") UUID customerId);
}
