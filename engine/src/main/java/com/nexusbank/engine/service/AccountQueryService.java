package com.nexusbank.engine.service;

import com.nexusbank.engine.dto.response.AccountBalanceResponse;
import com.nexusbank.engine.dto.response.PagedResponse;
import com.nexusbank.engine.dto.response.TransactionHistoryItem;
import com.nexusbank.engine.entity.Account;
import com.nexusbank.engine.entity.LedgerEntry;
import com.nexusbank.engine.repository.AccountRepository;
import com.nexusbank.engine.repository.LedgerEntryRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class AccountQueryService {

    private final AccountRepository accountRepository;
    private final LedgerEntryRepository ledgerEntryRepository;

    @Transactional(readOnly = true)
    public AccountBalanceResponse getBalance(UUID accountId, LocalDate asOfDate) {
        Account account = accountRepository.findById(accountId)
            .orElseThrow(() -> new RuntimeException("Account not found: " + accountId));

        BigDecimal balance;
        if (asOfDate != null) {
            balance = ledgerEntryRepository.findBalanceAsOf(accountId, asOfDate)
                .orElse(BigDecimal.ZERO);
        } else {
            balance = ledgerEntryRepository.findCurrentBalance(accountId)
                .orElse(BigDecimal.ZERO);
            asOfDate = LocalDate.now();
        }

        log.debug("Balance for account {} as of {}: {}", accountId, asOfDate, balance);

        return AccountBalanceResponse.builder()
            .accountId(account.getAccountId())
            .accountNumber(account.getAccountNumber())
            .accountType(account.getAccountType())
            .currencyCode(account.getCurrencyCode())
            .currentBalance(balance)
            .asOfDate(asOfDate)
            .build();
    }

    @Transactional(readOnly = true)
    public PagedResponse<TransactionHistoryItem> getTransactionHistory(
        UUID accountId, LocalDate fromDate, LocalDate toDate, int page, int size) {

        if (!accountRepository.existsById(accountId)) {
            throw new RuntimeException("Account not found: " + accountId);
        }

        if (fromDate == null) fromDate = LocalDate.now().minusMonths(1);
        if (toDate == null) toDate = LocalDate.now();

        PageRequest pageRequest = PageRequest.of(page, size, Sort.by("entry_date").descending());
        Page<LedgerEntry> entries = ledgerEntryRepository
            .findTransactionHistory(accountId, fromDate, toDate, pageRequest);

        var content = entries.getContent().stream()
            .map(entry -> TransactionHistoryItem.builder()
                .transactionId(entry.getTransaction().getTransactionId())
                .transactionType(entry.getTransaction().getTransactionType())
                .status(entry.getTransaction().getStatus())
                .businessDate(entry.getTransaction().getBusinessDate())
                .description(entry.getDescription())
                .entryType(entry.getEntryType())
                .amount(entry.getAmount())
                .balanceAfter(entry.getBalanceAfter())
                .build())
            .collect(Collectors.toList());

        return PagedResponse.<TransactionHistoryItem>builder()
            .content(content)
            .page(entries.getNumber())
            .size(entries.getSize())
            .totalElements(entries.getTotalElements())
            .totalPages(entries.getTotalPages())
            .last(entries.isLast())
            .build();
    }
}
