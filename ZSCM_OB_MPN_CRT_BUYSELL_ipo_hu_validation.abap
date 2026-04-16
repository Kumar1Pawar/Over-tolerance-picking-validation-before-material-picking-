*&---------------------------------------------------------------------*
*& ZSCM_OB_MPN_CRT_BUYSELL - IPO vs picking (HU) validation
*& FS: FS- Updated logic for Validation over tolerance picking and IPO qty
*& Insert before processing at ~line 48 (per functional specification).
*& Rules: FOR ALL ENTRIES on EKET (no INNER JOIN); no external API here.
*& Rename ls_it_header components if your IT_HEADER uses other field names.
*&---------------------------------------------------------------------*
* Sum IT_HEADER-HU_QTY per IPO_NO / IPO_ITEM.
* EKET: EBELN = IPO_NO, EBELP = IPO_ITEM → aggregate MENG, GLMNG.
* Allowed qty = SUM(MENG) - SUM(GLMNG). If sum(HU_QTY) > allowed → error.
* Message: "IPO Qty is less than picking qty"
*&---------------------------------------------------------------------*

  TYPES: BEGIN OF ty_zscm_hu_sum,
           ebeln  TYPE ebeln,
           ebelp  TYPE ebelp,
           hu_sum TYPE menge_d,
         END OF ty_zscm_hu_sum,
         BEGIN OF ty_zscm_eket_key,
           ebeln TYPE ebeln,
           ebelp TYPE ebelp,
         END OF ty_zscm_eket_key,
         BEGIN OF ty_zscm_eket_agg,
           ebeln     TYPE ebeln,
           ebelp     TYPE ebelp,
           sum_meng  TYPE menge_d,
           sum_glmng TYPE menge_d,
         END OF ty_zscm_eket_agg.

  DATA: lt_hu_sum    TYPE HASHED TABLE OF ty_zscm_hu_sum WITH UNIQUE KEY ebeln ebelp,
        ls_hu_sum    TYPE ty_zscm_hu_sum,
        lt_eket_keys TYPE SORTED TABLE OF ty_zscm_eket_key WITH UNIQUE KEY ebeln ebelp,
        ls_eket_key  TYPE ty_zscm_eket_key,
        lt_eket_agg  TYPE HASHED TABLE OF ty_zscm_eket_agg WITH UNIQUE KEY ebeln ebelp,
        ls_eket_agg  TYPE ty_zscm_eket_agg,
        lv_diff_qty  TYPE menge_d.

  FIELD-SYMBOLS: <ls_sum> TYPE ty_zscm_hu_sum.

*--- Sum HU_QTY per IPO_NO / IPO_ITEM (maps to EKET-EBELN / EBELP)
  LOOP AT it_header INTO DATA(ls_it_header).
    READ TABLE lt_hu_sum WITH TABLE KEY ebeln = ls_it_header-ipo_no
                                        ebelp = ls_it_header-ipo_item
           ASSIGNING <ls_sum>.
    IF sy-subrc = 0.
      <ls_sum>-hu_sum = <ls_sum>-hu_sum + ls_it_header-hu_qty.
    ELSE.
      CLEAR ls_hu_sum.
      ls_hu_sum-ebeln  = ls_it_header-ipo_no.
      ls_hu_sum-ebelp  = ls_it_header-ipo_item.
      ls_hu_sum-hu_sum = ls_it_header-hu_qty.
      INSERT ls_hu_sum INTO TABLE lt_hu_sum.
    ENDIF.
  ENDLOOP.

*--- Driver keys for EKET (unique EBELN / EBELP)
  LOOP AT lt_hu_sum INTO ls_hu_sum.
    CLEAR ls_eket_key.
    ls_eket_key-ebeln = ls_hu_sum-ebeln.
    ls_eket_key-ebelp = ls_hu_sum-ebelp.
    INSERT ls_eket_key INTO TABLE lt_eket_keys.
  ENDLOOP.

  IF lt_eket_keys IS NOT INITIAL.

    SELECT ebeln, ebelp, meng, glmng
      FROM eket
      FOR ALL ENTRIES IN @lt_eket_keys
      WHERE ebeln = @lt_eket_keys-ebeln
        AND ebelp = @lt_eket_keys-ebelp
      INTO TABLE @DATA(lt_eket).

    LOOP AT lt_eket INTO DATA(ls_eket).
      READ TABLE lt_eket_agg WITH TABLE KEY ebeln = ls_eket-ebeln
                                            ebelp = ls_eket-ebelp
             ASSIGNING FIELD-SYMBOL(<ls_agg>).
      IF sy-subrc = 0.
        <ls_agg>-sum_meng  = <ls_agg>-sum_meng  + ls_eket-meng.
        <ls_agg>-sum_glmng = <ls_agg>-sum_glmng + ls_eket-glmng.
      ELSE.
        CLEAR ls_eket_agg.
        ls_eket_agg-ebeln     = ls_eket-ebeln.
        ls_eket_agg-ebelp     = ls_eket-ebelp.
        ls_eket_agg-sum_meng  = ls_eket-meng.
        ls_eket_agg-sum_glmng = ls_eket-glmng.
        INSERT ls_eket_agg INTO TABLE lt_eket_agg.
      ENDIF.
    ENDLOOP.

  ENDIF.

*--- Compare summed HU_QTY with SUM(MENG) - SUM(GLMNG) per IPO line
  LOOP AT lt_hu_sum INTO ls_hu_sum.
    READ TABLE lt_eket_agg WITH TABLE KEY ebeln = ls_hu_sum-ebeln
                                          ebelp = ls_hu_sum-ebelp
           ASSIGNING FIELD-SYMBOL(<ls_eket_sum>).
    IF sy-subrc <> 0.
      CONTINUE.
    ENDIF.

    CLEAR lv_diff_qty.
    lv_diff_qty = <ls_eket_sum>-sum_meng - <ls_eket_sum>-sum_glmng.

    IF ls_hu_sum-hu_sum > lv_diff_qty.
      MESSAGE e000(zscm) WITH 'IPO Qty is less than picking qty'.
      RETURN.
    ENDIF.
  ENDLOOP.

