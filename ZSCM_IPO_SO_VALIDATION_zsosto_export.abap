*&---------------------------------------------------------------------*
*& ZSCM_IPO_SO_VALIDATION - export: ZSOSTO to Z_PNC_RPL_SO_IPO_LINK
*& After LIPS read. Adjust ZSOSTO fields to DDIC.
*&---------------------------------------------------------------------*

  DATA: lv_link_vbeln TYPE vbeln_va,
        lv_link_posnr TYPE posnr_va.

  SELECT SINGLE vbeln so_posnr
    FROM zsosto
    INTO (@lv_link_vbeln, @lv_link_posnr)
    WHERE vgbel = @ls_lips-vgbel
      AND vgpos = @ls_lips-vgpos.

  IF sy-subrc = 0.
    CALL FUNCTION ''Z_PNC_RPL_SO_IPO_LINK''
      EXPORTING
        im_vbeln = lv_link_vbeln
        im_posnr = lv_link_posnr
      .
  ELSE.
    CALL FUNCTION ''Z_PNC_RPL_SO_IPO_LINK''
      EXPORTING
        im_vbeln = ls_lips-vgbel
        im_posnr = ls_lips-vgpos
      .
  ENDIF.