"! <p class="shorttext synchronized" lang="de">Impl.-Klasse für dynamisches RRI</p>
"! BAdI-Implementierung zu RS_BBS_BADI_DYNAMIC (Enhancement-Spot RS_BBS_DYNAMIC_ENHS).
"! Liefert zur Laufzeit die Sprungziele (RRI-Sets) eines InfoProviders und
"! baut über ZCL_RRI_DYN_SRV die URL für den Absprung (WebGUI-Transaktion oder Fiori-App).
"!
"! Steuertabellen:
"!   ZRRI_00  RRI System und URL           (SM30)
"!   ZRRI_10  RRI-Sets                     (Viewcluster ZRRI_VC / View ZRRI_80)
"!   ZRRI_11  RRI-Parameter-Mapping        (Viewcluster ZRRI_VC / View ZRRI_81)
"!   ZRRI_12  RRI-Zuordnung InfoProvider   (Viewcluster ZRRI_VC / View ZRRI_82)
CLASS zcl_rri_dyn_impl DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES if_badi_interface.
    INTERFACES if_rs_bbs_badi_handler_dynamic.
    INTERFACES if_rs_bbs_badi_dynamic.
    INTERFACES if_rs_bbs_badi_dynamic_ina.

    "! Applikationskennung des dynamischen Sprungziels (RSBBS, 4 Zeichen)
    CONSTANTS gc_appl TYPE c LENGTH 4 VALUE 'ZRR1'.

    METHODS constructor.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_rri_dyn_impl IMPLEMENTATION.


  METHOD constructor.
    " RFC-Aufrufe aus diesem Handler erlauben?
    if_rs_bbs_badi_handler_dynamic~n_remote           = rs_c_false.
    " SAP-GUI-Aufrufe aus diesem Handler erlauben?
    if_rs_bbs_badi_handler_dynamic~n_sapgui_call      = rs_c_false.
    " Selektions-Handle (Clustertabellen) verwenden?
    if_rs_bbs_badi_handler_dynamic~n_selection_handle = rs_c_true.
    " URL-Aufrufe aus diesem Handler erlauben?
    if_rs_bbs_badi_handler_dynamic~n_url_call         = rs_c_true.
  ENDMETHOD.


  METHOD if_rs_bbs_badi_dynamic_ina~is_ina_enabled.
    r_ina_enabled = abap_false.
  ENDMETHOD.


  METHOD if_rs_bbs_badi_dynamic_ina~is_static_context.
    r_is_static_context = abap_false.
  ENDMETHOD.


  METHOD if_rs_bbs_badi_dynamic~get_types.

    DATA ls_handler TYPE rsbbs_s_badi_handler_dyn.

    " Handler nur erzeugen, wenn der Provider mindestens einem RRI-Set zugeordnet ist:
    SELECT SINGLE setid
      FROM zrri_12                                        " RRI-Zuordnung
      INTO @DATA(lv_setid)
      WHERE infoprov = @i_infocube.

    IF sy-subrc = 0.
      ls_handler-appl = gc_appl.
      " ABAP-Klasse, die IF_RS_BBS_BADI_HANDLER_DYNAMIC implementiert:
      CREATE OBJECT ls_handler-handler TYPE zcl_rri_dyn_impl.
      INSERT ls_handler INTO TABLE c_th_handler.
    ENDIF.

  ENDMETHOD.


  METHOD if_rs_bbs_badi_handler_dynamic~call_batch.
  ENDMETHOD.


  METHOD if_rs_bbs_badi_handler_dynamic~call_sapgui.
  ENDMETHOD.


  METHOD if_rs_bbs_badi_handler_dynamic~call_url.

    DATA(lr_rri_srv) = NEW zcl_rri_dyn_srv( ).

    r_url = lr_rri_srv->prepare_url(
              i_infoprov    = i_infoprov
              i_thx_mapping = i_thx_mapping
              i_onam        = i_onam ).

  ENDMETHOD.


  METHOD if_rs_bbs_badi_handler_dynamic~get_targets.

    DATA ls_f4_list TYPE rstirep.

    " Quellfeld des Absprungs ermitteln:
    READ TABLE i_thx_mapping
      ASSIGNING FIELD-SYMBOL(<fs_sourcefield>)
      WITH KEY mdflag = abap_true.

    IF <fs_sourcefield> IS ASSIGNED.
      " RRI-Sets zum Feld und zum aktuellen InfoProvider lesen:
      SELECT zrri_10~besid,
             zrri_10~setid,
             zrri_10~sourceiobj,
             zrri_10~numb,
             zrri_10~text
        FROM zrri_10                                      " RRI-Sets (Kopfdaten)
        INNER JOIN zrri_12                                " RRI-Zuordnung
          ON  zrri_10~besid = zrri_12~besid
          AND zrri_10~setid = zrri_12~setid
        WHERE zrri_10~sourceiobj = @<fs_sourcefield>-fieldnm
          AND zrri_12~infoprov   = @i_infocube
        INTO TABLE @DATA(lt_f4_list).

      LOOP AT lt_f4_list ASSIGNING FIELD-SYMBOL(<fs_f4_list>).
        CLEAR ls_f4_list.
        ls_f4_list-appl = gc_appl.
        " Objekt-Key: Besitzer & Set & InfoObjekt & Nummer (wird in CALL_URL wieder zerlegt)
        ls_f4_list-onam = zcl_rri_dyn_srv=>build_onam(
                            i_besid      = <fs_f4_list>-besid
                            i_setid      = <fs_f4_list>-setid
                            i_sourceiobj = <fs_f4_list>-sourceiobj
                            i_numb       = <fs_f4_list>-numb ).
        ls_f4_list-text = <fs_f4_list>-text.
        APPEND ls_f4_list TO e_t_f4_recivers_list.
      ENDLOOP.

    ENDIF.

  ENDMETHOD.
ENDCLASS.
