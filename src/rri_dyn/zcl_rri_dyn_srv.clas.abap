"! <p class="shorttext synchronized" lang="de">Service-Klasse für dynamisches RRI</p>
"! Baut aus den Steuertabellen ZRRI_00/10/11 und den von der RSBBS übergebenen
"! Feldwerten die Absprung-URL:
"!   RRI-Typ T: SAP GUI for HTML (WebGUI) mit Transaktion, Dynpro-Feldern und OK-Code
"!   RRI-Typ U: Fiori Launchpad mit semantischem Objekt, Aktion und Parametern
CLASS zcl_rri_dyn_srv DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    CONSTANTS:
      "! Trennzeichen im Objekt-Key (ONAM) des Sprungziels
      gc_onam_sep          TYPE c LENGTH 1 VALUE '&',
      "! RRI-Typ: Absprung auf Transaktion (WebGUI)
      gc_rrityp_transaction TYPE zrri_de_rrityp VALUE 'T',
      "! RRI-Typ: Absprung auf Fiori-URL (Launchpad)
      gc_rrityp_fiori       TYPE zrri_de_rrityp VALUE 'U',
      "! Pfad des SAP GUI for HTML im Zielsystem
      gc_path_webgui        TYPE string VALUE '/sap/bc/gui/sap/its/webgui',
      "! Pfad des Fiori Launchpads im Zielsystem
      gc_path_flp           TYPE string VALUE '/sap/bc/ui2/flp'.

    METHODS constructor.

    "! Absprung-URL für das gewählte Sprungziel aufbauen
    METHODS prepare_url
      IMPORTING
        !i_infoprov    TYPE rsinfoprov
        !i_thx_mapping TYPE rsbbs_thx_mapping
        !i_onam        TYPE rsti_onam
      RETURNING
        VALUE(r_url)   TYPE string
      RAISING
        cx_rs_error.

    "! Objekt-Key (ONAM) eines Sprungziels zusammensetzen
    CLASS-METHODS build_onam
      IMPORTING
        !i_besid      TYPE zrri_de_besid
        !i_setid      TYPE zrri_de_setid
        !i_sourceiobj TYPE rsiobjnm
        !i_numb       TYPE tvarv_numb
      RETURNING
        VALUE(r_onam) TYPE rsti_onam.

  PROTECTED SECTION.
  PRIVATE SECTION.

    DATA:
      gt_urls    TYPE HASHED TABLE OF zrri_00
                 WITH UNIQUE KEY logsys,
      gt_sets    TYPE HASHED TABLE OF zrri_10
                 WITH UNIQUE KEY besid setid sourceiobj numb,
      gt_mapping TYPE SORTED TABLE OF zrri_11
                 WITH UNIQUE KEY besid setid sourceiobj numb param.

    DATA gv_besid       TYPE zrri_de_besid.
    DATA gv_setid       TYPE zrri_de_setid.
    DATA gv_sourcefield TYPE rsd_fieldnm.
    DATA gv_numb        TYPE tvarv_numb.
    DATA gs_header      TYPE zrri_10.

    METHODS cache_metadata
      IMPORTING
        !i_onam TYPE rsti_onam.

    METHODS prepare_url_for_fiori
      IMPORTING
        !i_thx_mapping TYPE rsbbs_thx_mapping
      RETURNING
        VALUE(r_url)   TYPE string.

    METHODS prepare_url_for_transaction
      IMPORTING
        !i_thx_mapping TYPE rsbbs_thx_mapping
      RETURNING
        VALUE(r_url)   TYPE string.

    "! Ersten Einzelwert eines InfoObjekts aus der RSBBS-Übergabe lesen
    METHODS get_field_value
      IMPORTING
        !i_thx_mapping TYPE rsbbs_thx_mapping
        !i_iobjnm      TYPE rsiobjnm
      EXPORTING
        !e_value       TYPE string
        !e_found       TYPE abap_bool.

    "! Anmeldesprache im Zielsystem (ISO), Default = Anmeldesprache des Benutzers
    METHODS get_language
      IMPORTING
        !is_url        TYPE zrri_00
      RETURNING
        VALUE(r_laiso) TYPE laiso.
ENDCLASS.



CLASS zcl_rri_dyn_srv IMPLEMENTATION.


  METHOD build_onam.
    r_onam = |{ i_besid }{ gc_onam_sep }{ i_setid }{ gc_onam_sep }{ i_sourceiobj }{ gc_onam_sep }{ i_numb }|.
  ENDMETHOD.


  METHOD constructor.

    " Steuertabellen einlesen (Customizing, wenige Einträge):
    SELECT * FROM zrri_00 INTO TABLE @me->gt_urls.        "#EC CI_NOWHERE
    SELECT * FROM zrri_10 INTO TABLE @me->gt_sets.        "#EC CI_NOWHERE
    SELECT * FROM zrri_11 INTO TABLE @me->gt_mapping.     "#EC CI_NOWHERE

  ENDMETHOD.


  METHOD cache_metadata.

    " Besitzer-ID, Set-ID, InfoObjekt und Nummer aus dem Objekt-Key lesen
    " (Aufbau siehe BUILD_ONAM):
    SPLIT i_onam AT gc_onam_sep
      INTO me->gv_besid me->gv_setid me->gv_sourcefield me->gv_numb.

    " Kopfzeile (RRI-Set) lesen:
    READ TABLE me->gt_sets
      WITH TABLE KEY besid      = me->gv_besid
                     setid      = me->gv_setid
                     sourceiobj = me->gv_sourcefield
                     numb       = me->gv_numb
      INTO me->gs_header.

  ENDMETHOD.


  METHOD prepare_url.

    " 1. Metadaten zum Sprungziel lesen:
    " (I_INFOPROV bleibt für Erweiterungen in der Signatur, die Zuordnung
    "  Provider -> Besitzer/Set steckt bereits im Objekt-Key)
    me->cache_metadata( i_onam ).

    " 2. Verarbeitungsmodus bestimmen:
    CASE me->gs_header-rrityp.
      WHEN gc_rrityp_transaction.
        r_url = me->prepare_url_for_transaction( i_thx_mapping ).
      WHEN gc_rrityp_fiori.
        r_url = me->prepare_url_for_fiori( i_thx_mapping ).
    ENDCASE.

  ENDMETHOD.


  METHOD prepare_url_for_fiori.

    DATA lv_value TYPE string.
    DATA lv_found TYPE abap_bool.

    READ TABLE me->gt_urls ASSIGNING FIELD-SYMBOL(<fs_url>)
      WITH TABLE KEY logsys = gs_header-logsys.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    " Basis: <URL>/sap/bc/ui2/flp?sap-client=...&sap-language=...#<SemObj>-<Action>
    r_url = |{ <fs_url>-url }{ gc_path_flp }|.
    DATA(lv_sep) = `?`.
    IF <fs_url>-sapclient IS NOT INITIAL.
      r_url = |{ r_url }{ lv_sep }sap-client={ <fs_url>-sapclient }|.
      lv_sep = `&`.
    ENDIF.
    IF <fs_url>-saplangu IS NOT INITIAL.
      r_url = |{ r_url }{ lv_sep }sap-language={ <fs_url>-saplangu }|.
    ENDIF.
    r_url = |{ r_url }#{ gs_header-tcode }-{ gs_header-okcode }|.

    " Parameter-Mapping anhängen:
    lv_sep = `?`.
    LOOP AT me->gt_mapping ASSIGNING FIELD-SYMBOL(<fs_mapping>)
      WHERE besid      = me->gv_besid
        AND setid      = me->gv_setid
        AND sourceiobj = me->gv_sourcefield
        AND numb       = me->gv_numb.

      IF <fs_mapping>-constant IS NOT INITIAL.
        " Konstante zugeordnet:
        r_url = |{ r_url }{ lv_sep }{ <fs_mapping>-param }={ <fs_mapping>-constant }|.
        lv_sep = `&`.
      ELSE.
        " Wert aus der RSBBS-Übergabe:
        get_field_value( EXPORTING i_thx_mapping = i_thx_mapping
                                   i_iobjnm      = <fs_mapping>-iobjnm
                         IMPORTING e_value       = lv_value
                                   e_found       = lv_found ).
        IF lv_found = abap_true.
          r_url = |{ r_url }{ lv_sep }{ <fs_mapping>-param }={ escape( val = lv_value format = cl_abap_format=>e_url_full ) }|.
          lv_sep = `&`.
        ENDIF.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


  METHOD prepare_url_for_transaction.

    DATA lv_value TYPE string.
    DATA lv_found TYPE abap_bool.

    READ TABLE me->gt_urls ASSIGNING FIELD-SYMBOL(<fs_url>)
      WITH TABLE KEY logsys = gs_header-logsys.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    " Basis: <URL>/sap/bc/gui/sap/its/webgui?sap-language=..&sap-client=..&~transaction=<TCODE> <Feld>=<Wert>;...
    r_url = |{ <fs_url>-url }{ gc_path_webgui }?sap-language={ get_language( <fs_url> ) }|.
    IF <fs_url>-sapclient IS NOT INITIAL.
      r_url = |{ r_url }&sap-client={ <fs_url>-sapclient }|.
    ENDIF.
    r_url = |{ r_url }&~transaction={ gs_header-tcode }%20|.

    " Parameter-Mapping (Dynpro-Felder) anhängen:
    LOOP AT me->gt_mapping ASSIGNING FIELD-SYMBOL(<fs_mapping>)
      WHERE besid      = me->gv_besid
        AND setid      = me->gv_setid
        AND sourceiobj = me->gv_sourcefield
        AND numb       = me->gv_numb.

      IF <fs_mapping>-constant IS NOT INITIAL.
        " Konstante zugeordnet:
        r_url = |{ r_url }{ <fs_mapping>-param }={ <fs_mapping>-constant };|.
      ELSE.
        " Wert aus der RSBBS-Übergabe:
        get_field_value( EXPORTING i_thx_mapping = i_thx_mapping
                                   i_iobjnm      = <fs_mapping>-iobjnm
                         IMPORTING e_value       = lv_value
                                   e_found       = lv_found ).
        IF lv_found = abap_true.
          r_url = |{ r_url }{ <fs_mapping>-param }={ lv_value };|.
        ELSE.
          r_url = |{ r_url };|.
        ENDIF.
      ENDIF.

    ENDLOOP.

    " OK-Code aus dem RRI-Set anhängen:
    r_url = |{ r_url }DYNP_OKCODE=SHOW&~OKCODE={ gs_header-okcode }#|.

  ENDMETHOD.


  METHOD get_field_value.

    CLEAR: e_value, e_found.

    LOOP AT i_thx_mapping ASSIGNING FIELD-SYMBOL(<fs_field_values>)
      WHERE fieldnm = i_iobjnm.                          "#EC CI_HASHSEQ
      LOOP AT <fs_field_values>-range ASSIGNING FIELD-SYMBOL(<fs_range>).
        e_value = <fs_range>-low.
        e_found = abap_true.
        RETURN.
      ENDLOOP.
    ENDLOOP.

  ENDMETHOD.


  METHOD get_language.

    r_laiso = is_url-saplangu.
    IF r_laiso IS INITIAL.
      CALL FUNCTION 'CONVERSION_EXIT_ISOLA_OUTPUT'
        EXPORTING
          input  = sy-langu
        IMPORTING
          output = r_laiso.
    ENDIF.

  ENDMETHOD.
ENDCLASS.
