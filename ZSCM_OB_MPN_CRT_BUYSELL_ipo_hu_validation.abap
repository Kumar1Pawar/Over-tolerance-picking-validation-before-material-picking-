*&---------------------------------------------------------------------*
*& ZSCM_OB_MPN_CRT_BUYSELL - IPO qty vs picking (HU) validation
*& Insert after existing EKPO query (per FS ~line 48).
*&---------------------------------------------------------------------*

  TYPES: BEGIN OF ty_zscm_hu_sum,
           ebeln TYPE ebeln,
           ebelp TYPE ebelp,
           hu_sum TYPE menge_d,
         END OF ty_zscm_hu_sum.

  DATA: lt_hu_sum TYPE HASHED TABLE OF ty_zscm_hu_sum WITH UNIQUE KEY ebeln ebelp,
        ls_hu_sum TYPE ty_zscm_hu_sum.

  LOOP AT it_header INTO DATA(ls_it_header).
    READ TABLE lt_hu_sum WITH TABLE KEY ebeln = ls_it_header-ipo_no
                                        ebelp = ls_it_header-ipo_item
           ASSIGNING FIELD-SYMBOL(<ls_sum>).
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

  LOOP AT lt_hu_sum INTO ls_hu_sum.
    SELECT SINGLE meng
      FROM ekpo
      INTO @DATA(lv_ekpo_meng)
      WHERE ebeln = @ls_hu_sum-ebeln
        AND ebelp = @ls_hu_sum-ebelp.

    IF sy-subrc <> 0.
      CONTINUE.
    ENDIF.

    IF ls_hu_sum-hu_sum > lv_ekpo_meng.
      MESSAGE e000(zscm) WITH 'IPO Qty is less than picking qty'.
      RETURN.
    ENDIF.
  ENDLOOP.
