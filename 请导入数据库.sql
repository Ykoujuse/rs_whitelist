CREATE TABLE `player_whitelist` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `whitelist_code` varchar(50) DEFAULT NULL,
  `license` varchar(255) DEFAULT NULL,
  `license2` varchar(255) DEFAULT NULL,
  `ip` varchar(255) DEFAULT NULL,
  `fivem` varchar(255) DEFAULT NULL,
  `steam` varchar(255) DEFAULT NULL,
  `live` varchar(255) DEFAULT NULL,
  `xbl` varchar(255) DEFAULT NULL,
  `create_time` datetime DEFAULT current_timestamp(),
  `create_by` varchar(255) DEFAULT NULL,
  `approved` tinyint(1) DEFAULT 0,
  `user_kook` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1076 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;