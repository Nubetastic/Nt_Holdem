(() => {
    const root = document.getElementById("blackjack");
    const entryFlow = document.getElementById("entry-flow");
    const setupPanel = document.getElementById("setup-panel");
    const joinPanel = document.getElementById("join-panel");
    const fullPanel = document.getElementById("full-panel");
    const actions = document.getElementById("actions");
    const timer = document.getElementById("timer");
    const stateLabel = document.getElementById("state-label");
    const leaveModal = document.getElementById("confirm-leave");
    const cameraButton = document.getElementById("camera-button");
    const scaleInput = document.getElementById("ui-scale");
    const propEditor = document.getElementById("prop-editor");
    const propGizmo = document.getElementById("prop-gizmo");
    let game = null;
    let pendingAction = false;
    let firstPersonActive = false;
    let cameraLookActive = false;
    let draggedAxis = null;
    let draggedMode = null;
    let lastPointer = null;
    let entryData = null;
    let selectedStakeName = null;
    let selectedDeckName = null;
    let setupDeadline = 0;
    let entrySubmitting = false;
    let selectedBetAmount = 0;
    let betContext = "";

    const stateNames = {
        WAITING: "Waiting", BLINDS: "Posting blinds", DEALING: "Dealing",
        BET_PREFLOP: "Pre-flop", FLOP: "Flop", BET_FLOP: "Flop betting",
        TURN: "Turn", BET_TURN: "Turn betting", RIVER: "River",
        BET_RIVER: "River betting", SHOWDOWN: "Showdown",
    };
    const suitNames = {
        C: "CLUBS", D: "DIAMONDS", H: "HEARTS", S: "SPADES",
    };

    const escapeHtml = (value) => String(value ?? "")
        .replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;")
        .replaceAll('"', "&quot;").replaceAll("'", "&#039;");
    const money = (value) => `$${Number(value || 0).toFixed(Number(value || 0) % 1 ? 2 : 0)}`;

    async function postNui(action, payload = {}) {
        const resource = typeof GetParentResourceName === "function" ? GetParentResourceName() : "Nt_Holdem";
        return fetch(`https://${resource}/${action}`, {
            method: "POST",
            headers: { "Content-Type": "application/json; charset=UTF-8" },
            body: JSON.stringify(payload),
        });
    }

    function closeEntry() {
        entryData = null;
        selectedStakeName = null;
        selectedDeckName = null;
        setupDeadline = 0;
        entrySubmitting = false;
        entryFlow.classList.add("hidden");
        setupPanel.classList.add("hidden");
        joinPanel.classList.add("hidden");
        fullPanel.classList.add("hidden");
    }

    function showEntryPanel(panel) {
        entrySubmitting = false;
        document.querySelectorAll(".entry-leave").forEach((button) => { button.disabled = false; });
        entryFlow.classList.remove("hidden");
        setupPanel.classList.toggle("hidden", panel !== setupPanel);
        joinPanel.classList.toggle("hidden", panel !== joinPanel);
        fullPanel.classList.toggle("hidden", panel !== fullPanel);
    }

    function settingLabel(name) {
        return String(name).replace(/([a-z])([A-Z])/g, "$1 $2").replaceAll("_", " ")
            .replace(/^./, (letter) => letter.toUpperCase());
    }

    function renderStakePreview() {
        const stake = entryData?.stakes?.[selectedStakeName];
        document.getElementById("selected-stake-label").textContent = stake?.label || selectedStakeName || "Select a stake";
        document.getElementById("selected-stake-values").innerHTML = stake
            ? Object.entries(stake).filter(([name]) => name !== "label" && name !== "NUIOrder").map(([name, value]) => `
                <div><span>${escapeHtml(settingLabel(name))}</span><strong>${typeof value === "number" ? money(value) : escapeHtml(value)}</strong></div>`).join("")
            : "<p>Choose a stake option to review its table values.</p>";
        document.getElementById("start-table").disabled = !selectedStakeName || !selectedDeckName;
    }

    function openSetup(data) {
        entryData = data;
        selectedStakeName = null;
        selectedDeckName = null;
        setupDeadline = Date.now() + Number(data.timeoutSeconds || 120) * 1000;
        document.getElementById("setup-table-name").textContent = data.tableLabel || "Texas Hold'em";
        document.querySelector(".npc-toggle").classList.toggle("hidden", data.enableNPC !== true || data.forceNPC === true);
        document.getElementById("allow-npcs").checked = data.forceNPC === true || data.enableNPC === true;
        document.getElementById("start-table").textContent = "Start table";
        document.getElementById("stake-options").innerHTML = Object.entries(data.stakes || {})
            .sort(([, a], [, b]) => Number(a.NUIOrder) - Number(b.NUIOrder)).map(([name, stake]) => `
            <button class="entry-option" type="button" data-stake="${escapeHtml(name)}">
                <strong>${escapeHtml(stake.label || name)}</strong><small>Blinds ${money(stake.smallBlind)} / ${money(stake.bigBlind)}</small>
            </button>`).join("");
        document.getElementById("deck-options").innerHTML = (data.decks || []).map((name) => `
            <button class="entry-option" type="button" data-deck="${escapeHtml(name)}"><strong>${escapeHtml(name)}</strong></button>`).join("");
        document.querySelectorAll("[data-stake]").forEach((button) => button.addEventListener("click", () => {
            selectedStakeName = button.dataset.stake;
            document.querySelectorAll("[data-stake]").forEach((option) => option.classList.toggle("selected", option === button));
            renderStakePreview();
        }));
        document.querySelectorAll("[data-deck]").forEach((button) => button.addEventListener("click", () => {
            selectedDeckName = button.dataset.deck;
            document.querySelectorAll("[data-deck]").forEach((option) => option.classList.toggle("selected", option === button));
            renderStakePreview();
        }));
        renderStakePreview();
        showEntryPanel(setupPanel);
    }

    function settingsHtml(data) {
        const stake = data.stake || {};
        return `
            <div><span>Stake</span><strong>${escapeHtml(stake.label || data.stakeName)}</strong></div>
            ${Object.entries(stake).filter(([name]) => name !== "label" && name !== "NUIOrder").map(([name, value]) => `
                <div><span>${escapeHtml(settingLabel(name))}</span><strong>${typeof value === "number" ? money(value) : escapeHtml(value)}</strong></div>`).join("")}
            <div><span>Card deck</span><strong>${escapeHtml(data.deckName)}</strong></div>
            <div><span>NPC players</span><strong>${data.allowNpcs ? "Enabled" : "Disabled"}</strong></div>`;
    }

    function openJoin(data) {
        entryData = data;
        document.getElementById("join-table").disabled = false;
        document.getElementById("join-table").textContent = "Join table";
        document.getElementById("join-table-name").textContent = data.tableLabel || "Texas Hold'em";
        document.getElementById("join-settings").innerHTML = settingsHtml(data);
        showEntryPanel(joinPanel);
    }

    function openFull(data) {
        entryData = data;
        document.getElementById("full-table-name").textContent = data.tableLabel || "No open seats";
        showEntryPanel(fullPanel);
    }

    function stopCameraLook() {
        if (!cameraLookActive) return;
        cameraLookActive = false;
        postNui("cameraLook", { active: false });
    }

    window.addEventListener("mousedown", (event) => {
        if (event.button !== 2 || root.classList.contains("hidden") || !propEditor.classList.contains("hidden")) return;
        event.preventDefault();
        cameraLookActive = true;
        postNui("cameraLook", {
            active: true,
            x: event.clientX / window.innerWidth,
            y: event.clientY / window.innerHeight,
        });
    }, true);

    window.addEventListener("mouseup", (event) => {
        if (event.button === 2) stopCameraLook();
    }, true);

    window.addEventListener("contextmenu", (event) => {
        if (!root.classList.contains("hidden")) event.preventDefault();
    });

    function cardPath(card) {
        if (!card?.isRevealed) return "img/BACK.png";
        const royalty = card.royalty === "T" ? "10" : card.royalty;
        return `img/${royalty}_${suitNames[card.suit.toUpperCase()]}.png`;
    }

    function cardsHtml(cards, className = "card") {
        if (!cards?.length) return '<span class="muted">No cards dealt</span>';
        if (className === "mini-card") {
            return cards.map((card) => `<span class="mini-card"><img src="${cardPath(card)}" alt="${card?.isRevealed ? escapeHtml(card.royalty + card.suit) : "Hidden card"}"></span>`).join("");
        }
        return cards.map((card) => `<img class="${className}" src="${cardPath(card)}" alt="${card?.isRevealed ? escapeHtml(card.royalty + card.suit) : "Hidden card"}">`).join("");
    }

    async function send(action, payload = {}) {
        if (pendingAction) return;
        pendingAction = true;
        renderActions();
        try {
            await postNui(action, { handId: game?.handId, ...payload });
        } finally {
            window.setTimeout(() => {
                pendingAction = false;
                renderActions();
            }, 600);
        }
    }

    function renderPlayers() {
        const rows = game?.players || [];
        const winners = new Set((game?.winners || []).map((winner) => String(winner.source)));
        document.getElementById("player-count").textContent = String(rows.length);
        document.getElementById("players-list").innerHTML = rows.map((player) => {
            const status = player.waiting ? "Next hand" : player.folded ? "Folded"
                : player.result || (player.inHand ? (player.isCurrent ? "Acting" : "In hand") : "Seated");
            return `
                <article class="player-row ${player.isCurrent ? "current" : ""} ${player.isSelf ? "self" : ""} ${player.isNpc ? "npc" : ""} ${winners.has(String(player.source)) ? "winner" : ""}">
                    <div class="player-row-head">
                        <strong>Seat ${player.seatIndex}${player.isDealer ? " · Dealer" : ""}${player.isSmallBlind ? " · Small blind" : ""}${player.isBigBlind ? " · Big blind" : ""}</strong>
                        <span>${escapeHtml(player.name)}${player.isSelf ? " (You)" : player.isNpc ? " (NPC)" : ""}</span>
                    </div>
                    <div class="player-row-meta"><span>${escapeHtml(status)}</span><span>${money(player.totalBet)}</span></div>
                    <div class="player-row-hands"><div class="player-row-hand"><div class="mini-cards">${cardsHtml(player.holeCards, "mini-card")}</div></div></div>
                </article>`;
        }).join("");
    }

    function renderHands() {
        const cards = game?.self?.holeCards || [];
        const container = document.getElementById("player-hands");
        if (game?.winners?.length) {
            const names = game.winners.map((winner) => escapeHtml(winner.name)).join(" & ");
            const amount = game.winners.length === 1 ? money(game.winners[0].amount) : `${money(game.winners[0].amount)} each`;
            const hands = [...new Set(game.winners.map((winner) => winner.hand).filter(Boolean))]
                .map((hand) => escapeHtml(hand)).join(" & ");
            container.innerHTML = `
                <div class="winner-overlay">
                    <span>${game.winners.length === 1 ? "Winner" : "Split pot"}</span>
                    <strong>${names}</strong>
                    <small>${hands ? `Won with ${hands} · ` : ""}${amount}</small>
                </div>`;
            return;
        }
        if (!cards.length) {
            container.innerHTML = '<div class="action-message">Waiting for blinds and cards.</div>';
            return;
        }
        container.innerHTML = `
            <article class="hand ${game.isMyTurn ? "active" : ""}">
                <div class="hand-title"><span>Hole cards</span><strong>${game.isMyTurn ? "Your turn" : "In play"}</strong><span>${money(game.pot)} pot</span></div>
                <div class="cards">${cardsHtml(cards)}</div>
            </article>`;
    }

    function renderActions() {
        if (!game) return;
        const allowed = game.allowedActions || {};
        if (game.isMyTurn) {
            const minimumAmount = Number(allowed.callAmount || 0);
            const maximumAmount = Number(allowed.maximumAmount || 0);
            const increment = Number(game.rules.betIncrement || 0);
            const context = `${game.handId}:${game.state}:${game.currentSource}:${minimumAmount}:${maximumAmount}`;
            if (context !== betContext) {
                betContext = context;
                selectedBetAmount = minimumAmount;
            }
            selectedBetAmount = Math.max(minimumAmount, Math.min(maximumAmount, selectedBetAmount));
            const canDecrease = selectedBetAmount - increment >= minimumAmount;
            const canIncrease = selectedBetAmount < maximumAmount;
            const isAllIn = allowed.maximumAllIn && selectedBetAmount === maximumAmount;
            const canRaise = allowed.raise && selectedBetAmount > minimumAmount
                && (selectedBetAmount >= minimumAmount + increment || isAllIn);
            actions.innerHTML = `
                <div class="bet-box">
                    <label>Amount to put in · Max ${money(maximumAmount)}</label>
                    <div class="bet-amount-control">
                        <button type="button" data-bet-delta="-${increment}" ${!canDecrease || pendingAction ? "disabled" : ""} aria-label="Decrease bet">&#9664;</button>
                        <strong>${money(selectedBetAmount)}</strong>
                        <button type="button" data-bet-delta="${increment}" ${!canIncrease || pendingAction ? "disabled" : ""} aria-label="Increase bet">&#9654;</button>
                    </div>
                </div>
                <button class="action-button" data-action="check" ${!allowed.check || pendingAction ? "disabled" : ""}>Check</button>
                <button class="action-button" data-action="call" ${!allowed.call || pendingAction ? "disabled" : ""}>${allowed.callAllIn ? "All In" : "Call"}${allowed.callAmount ? " " + money(allowed.callAmount) : ""}</button>
                <button class="action-button" data-action="raise" ${!canRaise || pendingAction ? "disabled" : ""}>${isAllIn ? "All In" : "Raise"} ${money(selectedBetAmount)}</button>
                <button class="action-button danger" data-action="fold" ${!allowed.fold || pendingAction ? "disabled" : ""}>Fold</button>`;
        } else {
            const messages = {
                WAITING: "Waiting for the next hand.",
                BLINDS: game.self?.waiting ? "You will enter on the next hand." : "The small and big blinds are being posted.",
                DEALING: "The player dealer is dealing face-down hole cards.",
                FLOP: "The dealer is placing the flop.", TURN: "The dealer is placing the turn.",
                RIVER: "The dealer is placing the river.",
                SHOWDOWN: "The pot is settled. The dealer rotates left after this hand.",
            };
            const fallback = game.currentName ? `Waiting for ${escapeHtml(game.currentName)}.` : "Waiting…";
            actions.innerHTML = `<div class="action-message">${messages[game.state] || fallback}</div>`;
        }
        actions.querySelectorAll("[data-action]").forEach((button) => button.addEventListener("click", () => {
            send(button.dataset.action, button.dataset.action === "raise" ? { amount: selectedBetAmount } : {});
        }));
        actions.querySelectorAll("[data-bet-delta]").forEach((button) => button.addEventListener("click", () => {
            selectedBetAmount += Number(button.dataset.betDelta);
            renderActions();
        }));
    }

    function updateTimer() {
        if (!game?.deadline) { timer.textContent = ""; return; }
        timer.textContent = `${Math.max(0, Math.ceil(game.deadline - Date.now() / 1000))}s`;
    }

    function render() {
        if (!game) return;
        document.getElementById("table-name").textContent = game.tableLabel || "Texas Hold'em";
        document.getElementById("player-name").textContent = game.self?.name || "Player";
        document.getElementById("cash-value").textContent = money(game.self?.cash);
        document.getElementById("minimum-bet").textContent = `${money(game.rules?.smallBlind)} / ${money(game.rules?.bigBlind)}`;
        document.getElementById("maximum-bet").textContent = money(game.rules?.betIncrement);
        document.getElementById("bet-step").textContent = game.dealerSeat ? `Seat ${game.dealerSeat}` : "-";
        document.getElementById("payout-label").textContent = money(game.pot);
        document.getElementById("dealer-rule").textContent = game.dealerSeat ? `Dealer: seat ${game.dealerSeat}` : "Dealer rotates left";
        document.getElementById("dealer-total").textContent = game.communityCards?.length
            ? `${game.communityCards.length} community card${game.communityCards.length === 1 ? "" : "s"}` : "Waiting for the flop";
        document.getElementById("dealer-cards").innerHTML = cardsHtml(game.communityCards);
        document.getElementById("shoe-cards").textContent = `${game.cardsRemaining || 0} cards in deck`;
        document.getElementById("shuffle-status").textContent = `Hand ${game.handId || 0} · fresh deck`;
        document.getElementById("turn-banner").textContent = game.isMyTurn ? "Your turn"
            : game.currentName ? `${game.currentName}'s turn` : (stateNames[game.state] || "Waiting");
        stateLabel.textContent = stateNames[game.state] || game.state;
        renderPlayers();
        renderHands();
        renderActions();
        updateTimer();
    }

    function setPanelScale(value) {
        const scale = Math.max(1, Math.min(1.5, Number(value) || 1));
        document.documentElement.style.setProperty("--ui-scale", String(scale));
        document.getElementById("ui-scale-value").textContent = `${Math.round(scale * 100)}%`;
    }

    function setFirstPerson(active) {
        firstPersonActive = active === true;
        root.classList.toggle("first-person", firstPersonActive);
        cameraButton.textContent = firstPersonActive ? "Return camera" : "First-person camera";
    }

    function renderGizmo(data) {
        if (!data.visible) { propGizmo.classList.add("hidden"); return; }
        propGizmo.classList.remove("hidden");
        const width = window.innerWidth;
        const height = window.innerHeight;
        const origin = { x: data.origin.x * width, y: data.origin.y * height };
        document.getElementById("gizmo-origin").setAttribute("cx", origin.x);
        document.getElementById("gizmo-origin").setAttribute("cy", origin.y);
        ["x", "y", "z"].forEach((axis) => {
            const endpoint = data.axes?.[axis];
            const group = propGizmo.querySelector(`[data-mode="translate"][data-axis="${axis}"]`);
            group.classList.toggle("hidden", !endpoint?.visible);
            if (endpoint?.visible) {
                const x = endpoint.x * width, y = endpoint.y * height;
                const line = group.querySelector("line"), circle = group.querySelector("circle");
                line.setAttribute("x1", origin.x); line.setAttribute("y1", origin.y); line.setAttribute("x2", x); line.setAttribute("y2", y);
                circle.setAttribute("cx", x); circle.setAttribute("cy", y);
            }
            const ring = data.rings?.[axis];
            const ringGroup = propGizmo.querySelector(`[data-mode="rotate"][data-axis="${axis}"]`);
            ringGroup.classList.toggle("hidden", !ring?.visible);
            if (ring?.visible) ringGroup.querySelector("polyline").setAttribute("points", ring.points.map((point) => `${point.x * width},${point.y * height}`).join(" "));
        });
    }

    propGizmo.addEventListener("pointerdown", (event) => {
        const target = event.target.closest("[data-axis]");
        if (!target) return;
        draggedAxis = target.dataset.axis;
        draggedMode = target.dataset.mode;
        lastPointer = { x: event.clientX, y: event.clientY };
        event.preventDefault();
    });
    window.addEventListener("pointermove", (event) => {
        if (!draggedAxis || !lastPointer) return;
        const dx = event.clientX - lastPointer.x;
        const dy = event.clientY - lastPointer.y;
        lastPointer = { x: event.clientX, y: event.clientY };
        postNui("propGizmoDrag", {
            axis: draggedAxis, mode: draggedMode,
            pixels: Math.abs(dx) > Math.abs(dy) ? dx : -dy,
            degrees: (dx - dy) * 0.25,
        });
    });
    window.addEventListener("pointerup", () => { draggedAxis = null; draggedMode = null; lastPointer = null; });

    window.addEventListener("message", (event) => {
        const data = event.data || {};
        if (data.type === "setupTable") openSetup(data.data || {});
        if (data.type === "joinDetails") openJoin(data.data || {});
        if (data.type === "tableFull") openFull(data.data || {});
        if (data.type === "closeEntry") closeEntry();
        if (data.type === "open") root.classList.remove("hidden");
        if (data.type === "state") { game = data.game; root.classList.remove("hidden"); render(); }
        if (data.type === "close") {
            game = null; pendingAction = false; cameraLookActive = false; setFirstPerson(false);
            root.classList.add("hidden"); leaveModal.classList.add("hidden"); closeEntry();
        }
        if (data.type === "cameraLook" && data.active === false) cameraLookActive = false;
        if (data.type === "propEditorOpen") propEditor.classList.remove("hidden");
        if (data.type === "propEditorClose") propEditor.classList.add("hidden");
        if (data.type === "propGizmoUpdate") renderGizmo(data);
    });

    document.getElementById("leave-button").addEventListener("click", () => leaveModal.classList.remove("hidden"));
    document.getElementById("cancel-leave").addEventListener("click", () => leaveModal.classList.add("hidden"));
    document.getElementById("confirm-leave-button").addEventListener("click", () => {
        leaveModal.classList.add("hidden");
        postNui("requestLeave");
    });
    document.getElementById("start-table").addEventListener("click", () => {
        if (!entryData || !selectedStakeName || !selectedDeckName) return;
        document.getElementById("start-table").disabled = true;
        document.getElementById("start-table").textContent = "Starting...";
        entrySubmitting = true;
        document.querySelectorAll(".entry-leave").forEach((button) => { button.disabled = true; });
        postNui("configureTable", {
            tableId: entryData.tableId,
            stakeName: selectedStakeName,
            deckName: selectedDeckName,
        allowNpcs: entryData.forceNPC === true
            || (entryData.enableNPC === true && document.getElementById("allow-npcs").checked),
        });
    });
    document.getElementById("join-table").addEventListener("click", () => {
        document.getElementById("join-table").disabled = true;
        document.getElementById("join-table").textContent = "Taking seat...";
        entrySubmitting = true;
        document.querySelectorAll(".entry-leave").forEach((button) => { button.disabled = true; });
        postNui("confirmJoin");
    });
    document.querySelectorAll(".entry-leave").forEach((button) => button.addEventListener("click", () => postNui("cancelEntry")));
    cameraButton.addEventListener("click", async () => {
        const response = await postNui("toggleFirstPerson");
        const result = await response.json().catch(() => null);
        if (result) setFirstPerson(result.active);
    });
    scaleInput.addEventListener("input", () => setPanelScale(Number(scaleInput.value) / 100));
    window.addEventListener("keyup", (event) => {
        if (event.key === "Escape" && !propEditor.classList.contains("hidden")) postNui("propGizmoClose");
        else if (event.key === "Escape" && !entryFlow.classList.contains("hidden") && !entrySubmitting) postNui("cancelEntry");
        else if (event.key === "Escape" && !root.classList.contains("hidden")) leaveModal.classList.remove("hidden");
    });
    setPanelScale(1);
    window.setInterval(() => {
        updateTimer();
        if (setupDeadline) {
            const seconds = Math.max(0, Math.ceil((setupDeadline - Date.now()) / 1000));
            document.getElementById("setup-timer").textContent = `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, "0")}`;
        }
    }, 250);
})();
