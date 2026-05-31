package com.nexusbank.engine.config;

import lombok.Data;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.reactive.function.client.WebClient;

@Configuration
public class RateApiConfig {

    @Bean
    @ConfigurationProperties(prefix = "app.rates")
    public RateApiProperties rateApiProperties() {
        return new RateApiProperties();
    }

    @Bean
    public WebClient fredWebClient(RateApiProperties props) {
        return WebClient.builder()
            .baseUrl(props.getFred().getBaseUrl())
            .build();
    }

    @Bean
    public WebClient ecbWebClient(RateApiProperties props) {
        return WebClient.builder()
            .baseUrl(props.getEcb().getBaseUrl())
            .build();
    }

    @Bean
    public WebClient currencyApiWebClient(RateApiProperties props) {
        return WebClient.builder()
            .baseUrl(props.getCurrencyApi().getBaseUrl())
            .defaultHeader("apikey", props.getCurrencyApi().getApiKey())
            .build();
    }

    @Data
    public static class RateApiProperties {
        private Fred fred = new Fred();
        private Ecb ecb = new Ecb();
        private CurrencyApi currencyApi = new CurrencyApi();
        private String ingestionCron = "0 0 6 * * *";

        @Data
        public static class Fred {
            private String apiKey;
            private String baseUrl = "https://api.stlouisfed.org/fred/series/observations";
        }

        @Data
        public static class Ecb {
            private String baseUrl = "https://data-api.ecb.europa.eu/service/data";
        }

        @Data
        public static class CurrencyApi {
            private String apiKey;
            private String baseUrl = "https://api.currencyapi.com/v3";
        }
    }
}
