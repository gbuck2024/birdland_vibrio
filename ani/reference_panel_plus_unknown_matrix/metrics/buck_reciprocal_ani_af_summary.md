# Buck Reciprocal ANI/AF Summary

Candidate calls are selected from non-Buck references using the highest reciprocal ANI; AF is then reported in both directions to show genome coverage. AF is `fragment_mappings / query_fragments`; reciprocal AF support requires both directions to be at least `0.50`.

| buck isolate | candidate species | ANI | Buck->ref AF | ref AF -> Buck | interpretation |
| --- | --- | --- | --- | --- | --- |
| Buck_BI0607_1_WKDL250009588-1A_233TFCLT4_L7 | Vibrio cidicii | 97.8414 | 0.2984 | 0.7683 | High ANI but incomplete reciprocal genome coverage; treat cautiously. |
| Buck_BI0607_2_WKDL250009588-1A_233TFCLT4_L7 | Vibrio vulnificus | 98.0584 | 0.1584 | 0.3671 | High ANI but incomplete reciprocal genome coverage; treat cautiously. |
| Buck_BS0607_9_WKDL250009588-1A_233TFCLT4_L7 | Vibrio vulnificus | 99.1897 | 0.1196 | 0.5206 | High ANI but incomplete reciprocal genome coverage; treat cautiously. |
| Buck_CB0707_82_WKDL250009588-1A_233TFCLT4_L7 | Vibrio vulnificus | 99.9531 | 0.4875 | 0.9337 | High ANI but incomplete reciprocal genome coverage; treat cautiously. |
| Buck_NB0507_14_WKDL250009588-1A_233TFCLT4_L7 | Vibrio vulnificus | 95.8304 | 0.2612 | 0.5310 | High ANI but incomplete reciprocal genome coverage; treat cautiously. |
| Buck_NB0507_8_WKDL250009588-1A_233TFCLT4_L7 | Vibrio vulnificus | 99.9608 | 0.9324 | 0.9643 | Strong species-level support; ANI is above threshold and reciprocal AF is adequate. |
