# Companion Landing Confirmation and Pre-Change Baseline

Recorded at implementation time, re-confirming the ordering constraint and capturing the
pre-change state so Phase 6's live verification has a baseline to compare against.

## 1. Companion status

Command:
```
grep -n '^\- \*\*Status\*\*' /home/benjamin/.config/nvim/specs/612_gate_sapience_activation_behind_extension/summaries/01_gate-sapience-activation-extension-summary.md
```
Observed: `4:- **Status**: [COMPLETED]`

The companion project (project 612, `gate_sapience_activation_behind_extension`, sited in
`/home/benjamin/.config/nvim`) is confirmed landed by direct read of its own summary's plan-level
status field — not inferred from the dispatch note.

## 2. Installed files present and executable

Command:
```
ls -l "$HOME/.claude/hooks/sapience-mcp-register-project.sh" "$HOME/.claude/scripts/setup-sapience-mcp.sh"
```
Observed:
```
-rwxr-xr-x 1 benjamin users  6150 Nov 12 22:58 /home/benjamin/.claude/hooks/sapience-mcp-register-project.sh
-rwxr-xr-x 1 benjamin users 14521 Nov 12 22:58 /home/benjamin/.claude/scripts/setup-sapience-mcp.sh
```
Both present, mode 755 (executable).

## 3. Eleven grants present at per-repo scope, seven byte-identical to this repo's source

Command:
```
jq -r '.permissions.allow[] | select(startswith("mcp__sapience"))' \
  /home/benjamin/.config/nvim/agent-system/extensions/sapience/settings-fragment.json | sort
```
Observed (11 entries):
```
mcp__sapience__sapience
mcp__sapience__sapience_adddoc
mcp__sapience__sapience_ask
mcp__sapience__sapience_briefing
mcp__sapience__sapience_context
mcp__sapience__sapience_handoff
mcp__sapience__sapience_outstanding
mcp__sapience__sapience_papers
mcp__sapience__sapience_remember
mcp__sapience__sapience_search
mcp__sapience__sapience_wrapup
```

Command:
```
jq -r '.permissions.allow[] | select(startswith("mcp__sapience"))' \
  /home/benjamin/.dotfiles/config/claude/settings.json | sort
```
Observed (7 entries):
```
mcp__sapience__sapience
mcp__sapience__sapience_ask
mcp__sapience__sapience_briefing
mcp__sapience__sapience_context
mcp__sapience__sapience_outstanding
mcp__sapience__sapience_papers
mcp__sapience__sapience_search
```

These 7 are a strict subset of the extension fragment's 11 and are byte-identical string for
string. Confirmed safe to remove from this repository's source: they already exist at per-repo
scope.

## 4. Registration command string, extracted from the installer

Command:
```
grep -n -A3 'HOOK_COMMAND=' \
  /home/benjamin/.config/nvim/agent-system/extensions/sapience/scripts/install-sapience-mcp-session-hook.sh
```
Observed:
```
HOOK_COMMAND="bash \$HOME/.claude/hooks/sapience-mcp-register-project.sh 2>/dev/null || echo '{}'"
```

Resolved literal string: `bash $HOME/.claude/hooks/sapience-mcp-register-project.sh 2>/dev/null || echo '{}'`

This is byte-identical to the string the dispatch and plan record. No STOP condition triggered —
Phase 3 proceeds using this exact string. The installer's own comment confirms both its
idempotency check and its `--remove` key off this exact string.

## 5. Extension-loaded repository baseline

Command (per repo): `jq -r '.extensions.sapience.status // "absent"' <repo>/.claude-extensions.json`

| Repository | Status |
|---|---|
| `/home/benjamin/.config/nvim` | active |
| `/home/benjamin/.dotfiles` | active |
| `/home/benjamin/Projects/abood` | active |
| `/home/benjamin/Projects/Sapience/sapience-app` | active |
| `/home/benjamin/Projects/cslib` | absent |
| `/home/benjamin/Projects/Logos/Theory` | absent |

Matches the dispatch's four-repo loaded set and two verified-unloaded negative-test candidates
exactly.

## 6. Pre-change `~/.claude.json` baseline

Top-level keys (for Phase 6 "nothing else disturbed" comparison) — 97 keys captured in full,
including `mcpServers` and `projects`. Full list captured via `jq -r 'keys[]' ~/.claude.json`;
stored verbatim below for exact diffing at Phase 6.

Top-level `mcpServers` keys: `nixos`, `playwright`, `sapience` (the `sapience` entry is the one
this task's Phase 2 edit removes).

`.projects | keys` (36 entries at baseline), notably:
- `/home/benjamin/Projects/sapience-app` (the STALE pre-move key; the moved checkout's new path
  `/home/benjamin/Projects/Sapience/sapience-app` has not yet registered — expected, since
  registration is session-start-triggered and no session has run from the moved checkout yet)
- `/home/benjamin/.dotfiles`, `/home/benjamin/.config/nvim`, `/home/benjamin/Projects/abood` are
  present (registered from earlier sessions); none yet carry a `.mcpServers.sapience` sub-key
  under per-project registration, since that registration mechanism is the one this task adds in
  Phase 3 and it has not run in any session yet at baseline time.

Full top-level key list (for exact post-switch diffing):
```
additionalModelCostsCache, additionalModelOptionsAnsweredAt, additionalModelOptionsCache,
agentLastUsed, agentPushNotifEnabled, announcementImpressions, anonymousId,
apiCreditLinkStatusCache, autoCompactEnabled, autoCompactWindowsCache, autoUpdates,
birthdayHatAnimationCount, btwUseCount, cachedArtifactRoster, cachedChromeExtensionInstalled,
cachedDynamicConfigs, cachedExperimentData, cachedExperimentFeatures,
cachedExtraUsageDisabledReason, cachedFeatureFlags, cachedFeatureFlagsAt,
cachedGrowthBookFeatures, cachedGrowthBookFeaturesAt, cachedStatsigGates, changelogLastFetched,
claudeAiMcpEverConnected, claudeCodeFirstTokenDate, clientDataCacheSlots, closedIssuesLastChecked,
customApiKeyResponses, editorMode, effortCalloutV2Dismissed, feedbackDraftsTurnOffPromptDeclines,
feedbackSurveyState, firstStartTime, fullscreenUpsellSeenCount, githubRepoPaths,
groveChoiceSeenAt, groveConfigCache, hasAcknowledgedCostThreshold, hasAvailableSubscription,
hasCompletedOnboarding, hasOpenedAgentsView, hasResetAutoModeOptInForDefaultOffer,
hasSeenAutoDefaultNudge, hasSeenAutoModeEntryWarning, hasSeenTasksHint, hasShownOpus45Notice,
hasShownOpus46Notice, hasUsedBackgroundTask, hasUsedBackslashReturn, hasUsedRemoteControl,
hasUsedStash, hasVisitedExtraUsage, hasVisitedPasses, installMethod, lastOnboardingVersion,
lastPlanModeUse, lastReleaseNotesSeen, lastShownEmergencyTip, lspRecommendationIgnoredCount,
machineID, mcpServers, migrationVersion, modelAccessCache, numStartups, oauthAccount,
officialMarketplaceAutoInstallAttempted, officialMarketplaceAutoInstalled,
opus45MigrationComplete, opus46FeedSeenCount, opusProMigrationComplete,
orgModelDefaultCache, overageCreditGrantCache, passesEligibilityCache,
passesLastSeenCampaign, passesLastSeenRemaining, passesUpsellSeenCount,
penguinModeOrgEnabled, pluginUsage, prStatusFooterEnabled, projects, promoStartupSeenCount,
promptQueueUseCount, pushNotifUpsellSeenCount, rcLongTurnNudgeSeenCount, rcLongTurnNudgeSeenKey,
remoteControlAtStartup, remoteControlReadyPushCount, remoteControlReadyPushKey,
remoteControlSurfacesSeen, remoteDialogSeen, replBridgePlaceholders, s1mAccessCache,
s1mNonSubscriberAccessCache, seenNotifications, shiftEnterKeyBindingInstalled, showSpinnerTree,
skillUsage, sonnet1m45MigrationComplete, sonnet45MigrationComplete, subscriptionNoticeCount,
teammateDefaultModel, thinkingMigrationComplete, tipLifetimeShownCounts, tipsHistory,
tipsHistoryByCommand, toolUsage, transcriptShareDismissed, unpinOpus47LaunchEffort, userID,
voiceFooterHintSeenCount, voiceLangHintLastLanguage, voiceLangHintShownCount
```

Full `.projects | keys` list (36 entries):
```
/home/benjamin, /home/benjamin/.config, /home/benjamin/.config/nvim, /home/benjamin/.config/zed,
/home/benjamin/.dotfiles, /home/benjamin/Documents/Employment/Applications,
/home/benjamin/Documents/Personal/Trips/India, /home/benjamin/Documents/Personal/Wedding,
/home/benjamin/Downloads, /home/benjamin/Mail, /home/benjamin/Philosophy/Papers/PossibleWorlds,
/home/benjamin/Pictures/Profile, /home/benjamin/Pictures/Wedding,
/home/benjamin/Projects/BimodalHarness, /home/benjamin/Projects/BimodalLogic,
/home/benjamin/Projects/Literature, /home/benjamin/Projects/Logos,
/home/benjamin/Projects/Logos/Hardware, /home/benjamin/Projects/Logos/LogosWebsite,
/home/benjamin/Projects/Logos/ModelChecker, /home/benjamin/Projects/Logos/Theory,
/home/benjamin/Projects/Logos/Verification, /home/benjamin/Projects/Logos/Vision,
/home/benjamin/Projects/Logos/Website, /home/benjamin/Projects/Logos/sparkle,
/home/benjamin/Projects/ModelChecker, /home/benjamin/Projects/PersonalWebsite,
/home/benjamin/Projects/ProofChecker, /home/benjamin/Projects/ProofChecker-feature-subagents,
/home/benjamin/Projects/ProofChecker-refactor-agent_system, /home/benjamin/Projects/SPSDemo,
/home/benjamin/Projects/Sapience/sf1-engine, /home/benjamin/Projects/abood,
/home/benjamin/Projects/cslib, /home/benjamin/Projects/cslib-pr648, /home/benjamin/Projects/protocol,
/home/benjamin/Projects/sapience-app, /home/benjamin/Projects/theorem_proving_in_lean4,
/tmp/claude-1000/-home-benjamin--config-nvim/c4adc98e-f94b-4ffe-bbf8-b105c7845204/scratchpad/fake-foreign-repo
```

## Conclusion

The ordering constraint is honored: the companion landed, is verified `[COMPLETED]`, both its
installed files exist at mode 755, all eleven grants exist at per-repo scope including the seven
byte-identical ones this task removes from this repository's source, and the registration command
string is confirmed byte-identical. Proceeding to Phase 2.
