admins = {
    "{{ .Env.JICOFO_AUTH_USER }}@{{ .Env.XMPP_AUTH_DOMAIN }}",
    "{{ .Env.JVB_AUTH_USER }}@{{ .Env.XMPP_AUTH_DOMAIN }}"
}

plugin_paths = { "/prosody-plugins-custom", "/prosody-plugins/" }
http_default_host = "{{ .Env.XMPP_DOMAIN }}"

{{ $ENABLE_AUTH := .Env.ENABLE_AUTH | default "0" | toBool }}
{{ $ENABLE_GUEST_DOMAIN := and $ENABLE_AUTH (.Env.ENABLE_GUESTS | default "0" | toBool)}}
{{ $AUTH_TYPE := .Env.AUTH_TYPE | default "internal" }}
{{ $JWT_ASAP_KEYSERVER := .Env.JWT_ASAP_KEYSERVER | default "" }}
{{ $JWT_ALLOW_EMPTY := .Env.JWT_ALLOW_EMPTY | default "0" | toBool }}
{{ $JWT_AUTH_TYPE := .Env.JWT_AUTH_TYPE | default "token" }}
{{ $JWT_TOKEN_AUTH_MODULE := .Env.JWT_TOKEN_AUTH_MODULE | default "token_verification" }}
{{ $ENABLE_LOBBY := .Env.ENABLE_LOBBY | default "0" | toBool }}

{{ $ENABLE_XMPP_WEBSOCKET := .Env.ENABLE_XMPP_WEBSOCKET | default "1" | toBool }}
{{ $ENABLE_INCOMING_BAN := .Env.ENABLE_INCOMING_BAN | default "0" | toBool }}

{{ if and $ENABLE_AUTH (eq $AUTH_TYPE "jwt") .Env.JWT_ACCEPTED_ISSUERS }}
asap_accepted_issuers = { "{{ join "\",\"" (splitList "," .Env.JWT_ACCEPTED_ISSUERS) }}" }
{{ end }}

{{ if $ENABLE_XMPP_WEBSOCKET }}
-- Deprecated in 0.12
-- https://github.com/bjc/prosody/commit/26542811eafd9c708a130272d7b7de77b92712de
cross_domain_websocket = { "{{ .Env.PUBLIC_URL }}", "{{ .Env.PUBLIC_URL }}:{{ .Env.HTTPS_PORT }}" };
consider_bosh_secure = true;
{{ end }}

default_tenant = "{{ .Env.DEFAULT_SITE_ID }}";
vmeeting_api_token = "{{ .Env.VMEETING_API_TOKEN }}";
enable_incoming_ban = {{ if $ENABLE_INCOMING_BAN }}true{{ else }}false{{ end }};

{{ if and $ENABLE_AUTH (eq $AUTH_TYPE "jwt") .Env.JWT_ACCEPTED_AUDIENCES }}
asap_accepted_audiences = { "{{ join "\",\"" (splitList "," .Env.JWT_ACCEPTED_AUDIENCES) }}" }
{{ end }}

-- domain mapper options, must at least have domain base set to use the mapper
muc_mapper_domain_base = "{{ .Env.XMPP_DOMAIN }}";
muc_mapper_domain_prefix = "{{ first (splitList "." .Env.XMPP_MUC_DOMAIN) }}";

VirtualHost "{{ .Env.XMPP_DOMAIN }}"
{{ if $ENABLE_AUTH }}
  {{ if eq $AUTH_TYPE "jwt" }}
    authentication = "{{ $JWT_AUTH_TYPE }}"
    app_id = "{{ .Env.JWT_APP_ID }}"
    app_secret = "{{ .Env.JWT_APP_SECRET }}"
    allow_empty_token = {{ if $JWT_ALLOW_EMPTY }}true{{ else }}false{{ end }}
    {{ if $JWT_ASAP_KEYSERVER }}
    asap_key_server = "{{ .Env.JWT_ASAP_KEYSERVER }}"
    {{ end }}

    {{ else if eq $AUTH_TYPE "ldap" }}
    authentication = "cyrus"
    cyrus_application_name = "xmpp"
    allow_unencrypted_plain_auth = true
  {{ else if eq $AUTH_TYPE "internal" }}
    authentication = "internal_hashed"
  {{ end }}
{{ else }}
  -- https://github.com/jitsi/docker-jitsi-meet/pull/502#issuecomment-619146339
  {{ if $ENABLE_XMPP_WEBSOCKET }}
  authentication = "token"
  {{ else }}
  authentication = "anonymous"
  {{ end }}
  app_id = ""
  app_secret = ""
  allow_empty_token = true
{{ end }}
    ssl = {
        key = "/config/certs/{{ .Env.XMPP_DOMAIN }}.key";
        certificate = "/config/certs/{{ .Env.XMPP_DOMAIN }}.crt";
    }
    modules_enabled = {
        "bosh";
        {{ if $ENABLE_XMPP_WEBSOCKET }}
        "websocket";
        "smacks"; -- XEP-0198: Stream Management
        {{ end }}
        "pubsub";
        "ping";
        "speakerstats";
        "conference_duration";
        {{ if $ENABLE_LOBBY }}
        "muc_lobby_rooms";
        {{ end }}
        {{ if .Env.XMPP_MODULES }}
        "{{ join "\";\n\"" (splitList "," .Env.XMPP_MODULES) }}";
        {{ end }}
        {{ if and $ENABLE_AUTH (eq $AUTH_TYPE "ldap") }}
        "auth_cyrus";
        {{end}}
        "site_license";
    }

    {{ if $ENABLE_LOBBY }}
    main_muc = "{{ .Env.XMPP_MUC_DOMAIN }}"
    lobby_muc = "lobby.{{ .Env.XMPP_DOMAIN }}"
    {{ if .Env.XMPP_RECORDER_DOMAIN }}
    muc_lobby_whitelist = { "{{ .Env.XMPP_RECORDER_DOMAIN }}" }
    {{ end }}
    {{ end }}

    speakerstats_component = "speakerstats.{{ .Env.XMPP_DOMAIN }}"
    conference_duration_component = "conferenceduration.{{ .Env.XMPP_DOMAIN }}"
    participant_log_component = "participantlog.{{ .Env.XMPP_DOMAIN }}"

    c2s_require_encryption = false
    bosh_max_inactivity = 120

{{ if $ENABLE_GUEST_DOMAIN }}
VirtualHost "{{ .Env.XMPP_GUEST_DOMAIN }}"
    -- https://github.com/jitsi/docker-jitsi-meet/pull/502#issuecomment-619146339
    {{ if $ENABLE_XMPP_WEBSOCKET }}
    authentication = "token"
    {{ else }}
    authentication = "anonymous"
    {{ end }}
    app_id = ""
    app_secret = ""
    allow_empty_token = true

    c2s_require_encryption = false

    {{ if $ENABLE_LOBBY }}
    modules_enabled = {
        "muc_lobby_rooms";
    }

    main_muc = "{{ .Env.XMPP_MUC_DOMAIN }}"
    lobby_muc = "lobby.{{ .Env.XMPP_DOMAIN }}"
    {{ if .Env.XMPP_RECORDER_DOMAIN }}
    muc_lobby_whitelist = { "{{ .Env.XMPP_RECORDER_DOMAIN }}" }
    {{ end }}
    {{ end }}

{{ end }}

VirtualHost "{{ .Env.XMPP_AUTH_DOMAIN }}"
    ssl = {
        key = "/config/certs/{{ .Env.XMPP_AUTH_DOMAIN }}.key";
        certificate = "/config/certs/{{ .Env.XMPP_AUTH_DOMAIN }}.crt";
    }
    authentication = "internal_hashed"

{{ if .Env.XMPP_RECORDER_DOMAIN }}
VirtualHost "{{ .Env.XMPP_RECORDER_DOMAIN }}"
    modules_enabled = {
      "ping";
    }
    authentication = "internal_hashed"
{{ end }}

Component "{{ .Env.XMPP_INTERNAL_MUC_DOMAIN }}" "muc"
    storage = "memory"
    modules_enabled = {
        "ping";
        {{ if .Env.XMPP_INTERNAL_MUC_MODULES }}
        "{{ join "\";\n\"" (splitList "," .Env.XMPP_INTERNAL_MUC_MODULES) }}";
        {{ end }}
    }
    muc_room_locking = false
    muc_room_default_public_jids = true

Component "{{ .Env.XMPP_MUC_DOMAIN }}" "muc"
    storage = "memory"
    modules_enabled = {
        "muc_meeting_id";
        "muc_domain_mapper";
        {{ if .Env.XMPP_MUC_MODULES }}
        "{{ join "\";\n\"" (splitList "," .Env.XMPP_MUC_MODULES) }}";
        {{ end }}
        {{ if and $ENABLE_AUTH (eq $AUTH_TYPE "jwt") }}
        "{{ $JWT_TOKEN_AUTH_MODULE }}";
        {{ end }}
        "participant_log";
        "site_license";
    }
    muc_room_cache_size = 1000
    muc_room_locking = false
    muc_room_default_public_jids = true
    {{ if .Env.XMPP_RECORDER_DOMAIN }}
    muc_lobby_whitelist = { "{{ .Env.XMPP_RECORDER_DOMAIN }}" }
    {{ else }}
    muc_lobby_whitelist = { }
    {{ end }}

Component "focus.{{ .Env.XMPP_DOMAIN }}"
    component_secret = "{{ .Env.JICOFO_COMPONENT_SECRET }}"

Component "speakerstats.{{ .Env.XMPP_DOMAIN }}" "speakerstats_component"
    muc_component = "{{ .Env.XMPP_MUC_DOMAIN }}"

Component "conferenceduration.{{ .Env.XMPP_DOMAIN }}" "conference_duration_component"
    muc_component = "{{ .Env.XMPP_MUC_DOMAIN }}"

Component "participantlog.{{ .Env.XMPP_DOMAIN }}" "participant_log_component"
    muc_component = "{{ .Env.XMPP_MUC_DOMAIN }}"

{{ if $ENABLE_LOBBY }}
Component "lobby.{{ .Env.XMPP_DOMAIN }}" "muc"
    storage = "memory"
    restrict_room_creation = true
    muc_room_locking = false
    muc_room_default_public_jids = true
{{ end }}
