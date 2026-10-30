# ha-waf-stack

Enterprise-grade High Availability Web Application Firewall — a production-ready, containerized security architecture combining load balancing, automatic failover, and real-time traffic inspection, protecting a full-stack .NET/Angular/PostgreSQL application.

Overview
This project implements a defense-in-depth web security architecture using Docker Compose. It places a highly available ModSecurity WAF (with the OWASP Core Rule Set) in front of a real-world application, ensuring every HTTP request is inspected before reaching the business logic — while the database remains fully isolated.
The architecture satisfies ISO/IEC 27001:2022 Annex A controls A.8.20 through A.8.23, with automated compliance test suites included.
