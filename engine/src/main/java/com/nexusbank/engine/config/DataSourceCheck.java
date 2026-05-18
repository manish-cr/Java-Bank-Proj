package com.nexusbank.engine.config;

import jakarta.annotation.PostConstruct;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Configuration;

import javax.sql.DataSource;
import java.sql.Connection;

@Configuration
public class DataSourceCheck {

    private static final Logger log = LoggerFactory.getLogger(DataSourceCheck.class);

    @Autowired
    private DataSource dataSource;

    @PostConstruct
    public void checkConnection() {
        try (Connection conn = dataSource.getConnection()) {
            log.info("===========================================");
            log.info(" DATABASE CONNECTION SUCCESSFUL");
            log.info(" URL: {}", conn.getMetaData().getURL());
            log.info(" DB Product: {} {}", conn.getMetaData().getDatabaseProductName(), conn.getMetaData().getDatabaseProductVersion());
            log.info("===========================================");
        } catch (Exception e) {
            log.error("!!! DATABASE CONNECTION FAILED: {}", e.getMessage());
        }
    }
}
