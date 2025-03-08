$(function() {
    let selectedPlayerId = null;
    let selectedIdentifier = null;
    let activeBans = [];
    let uiConfig = {
        durations: [],
    };
    
    
    function updateDurationOptions() {
        if (!uiConfig.durations || uiConfig.durations.length === 0) return;
        
        const banDuration = $('#banDuration, #offlineBanDuration, #editBanDuration');
        banDuration.empty();
        
        uiConfig.durations.forEach(duration => {
            banDuration.append(`<option value="${duration.value}">${duration.label}</option>`);
        });
        
    }

    function fixButtonLayout() {
        $('.submit-btn').each(function() {
            if (!$(this).parent().hasClass('button-container')) {
                $(this).wrap('<div class="button-container"></div>');
            }
        });
    }

    function setupResponsiveUI() {
        fixButtonLayout();
        
        $(window).on('resize', function() {
            fixButtonLayout();
        });
    }

    function initOfflineBanUI() {
        if (uiConfig.durations && uiConfig.durations.length > 0) {
            const offlineDuration = $('#offlineBanDuration');
            offlineDuration.empty();
            
            uiConfig.durations.forEach(duration => {
                offlineDuration.append(`<option value="${duration.value}">${duration.label}</option>`);
            });
        }
    }
    
    window.addEventListener('message', function(event) {
        const data = event.data;
        
        if (data.action === 'openBanMenu') {
            
            if (data.config) {
                uiConfig = data.config;
                updateDurationOptions();
                initOfflineBanUI();
            }
            
            $.post(`https://${GetParentResourceName()}/refreshBanList`, JSON.stringify({}));
            $('.container').fadeIn(300);
            
            if (data.target) {
                $('#selectedPlayerName').text(data.target.name);
                $('#selectedPlayerId').text(`ID: ${data.target.source}`);
                selectedPlayerId = data.target.source;
                
                $('.selected-player-avatar').addClass('pulse-animation');
                setTimeout(() => {
                    $('.selected-player-avatar').removeClass('pulse-animation');
                }, 2000);
                
                if (data.target.identifiers && data.target.identifiers.length > 0) {
                    selectedIdentifier = data.target.identifiers[0];
                }
            }
            
            if (data.bans && Array.isArray(data.bans)) {
                activeBans = data.bans;
                renderBanList(activeBans);
            }
            
            $.post(`https://${GetParentResourceName()}/getPlayers`, {}, function(response) {
                if (response.success && response.data) {
                    renderPlayerList(response.data);
                }
            });
            
            if (data.activeTab) {
                switchTab(data.activeTab);
            } else {
                switchTab('ban'); 
            }
            setupResponsiveUI();
        } else if (data.action === 'closeBanMenu') {
            $('.container').fadeOut(300);
        } else if (data.action === 'updateBanList') {
            if (data.bans && Array.isArray(data.bans)) {
                activeBans = data.bans;
                renderBanList(activeBans);
            }
        } else if (data.action === 'switchTab') {
            if (data.tab) {
                switchTab(data.tab);
            }
        } else if (data.action === 'notification') {
            showNotification(data.type, data.title || getNotificationTitle(data.type), data.message);
        }
    });
    
    
    
    function getNotificationTitle(type) {
        switch(type) {
            case 'success': return 'Success';
            case 'error': return 'Error';
            case 'warning': return 'Warning';
            default: return 'Information';
        }
    }
    
    function showNotification(type, title, message) {
        const icon = type === 'success' ? 'fas fa-check-circle' : 
                    type === 'error' ? 'fas fa-exclamation-triangle' :
                    type === 'warning' ? 'fas fa-exclamation-circle' : 'fas fa-info-circle';
        
        const notification = $(`
            <div class="notification ${type}">
                <i class="${icon}"></i>
                <div class="notification-content">
                    <div class="notification-title">${title}</div>
                    <div class="notification-message">${message}</div>
                </div>
                <div class="notification-close"><i class="fas fa-times"></i></div>
            </div>
        `);
        
        notification.find('.notification-close').on('click', function() {
            notification.fadeOut(300, function() {
                notification.remove();
            });
        });
        
        $('#notificationContainer').append(notification);
        
        setTimeout(() => {
            notification.fadeOut(300, function() {
                notification.remove();
            });
        }, 5000);
    }
    
    function renderPlayerList(players) {
        const playerList = $('#playerList');
        playerList.empty();
        
        if (!players || players.length === 0) {
            playerList.html(`
                <div class="no-players">
                    <i class="fas fa-users-slash"></i>
                    <div>No players online</div>
                </div>
            `);
            return;
        }
        
        players.forEach(player => {
            const playerItem = $(`
                <div class="player-item" data-id="${player.id}">
                    <div class="player-name">${escapeHtml(player.name)}</div>
                    <div class="player-id">ID: ${player.id}</div>
                </div>
            `);
            
            playerItem.on('click', function() {
                $('.player-item').removeClass('selected');
                $(this).addClass('selected');
                
                const playerId = $(this).data('id');
                
                $('#selectedPlayerName').text(player.name);
                $('#selectedPlayerId').text(`ID: ${player.id}`);
                selectedPlayerId = player.id;
                
                $('.selected-player-avatar').addClass('pulse-animation');
                setTimeout(() => {
                    $('.selected-player-avatar').removeClass('pulse-animation');
                }, 2000);
                
                $.post(`https://${GetParentResourceName()}/getPlayerIdentifiers`, JSON.stringify({
                    playerId: playerId
                }), function(response) {
                    if (response.success && response.target) {
                        if (response.target.identifiers && response.target.identifiers.length > 0) {
                            selectedIdentifier = response.target.identifiers[0];
                        }
                    }
                });
            });
            
            playerList.append(playerItem);
        });
    }
    
    function renderBanList(bans) {
        const banListBody = $('#banListBody');
        banListBody.empty();
        
        if (!bans || bans.length === 0) {
            banListBody.html(`
                <tr>
                    <td colspan="7">
                        <div class="no-bans">
                            <i class="fas fa-ban"></i>
                            <div>No active bans found</div>
                        </div>
                    </td>
                </tr>
            `);
            return;
        }
        
        bans.forEach(ban => {
            let badgeClass = "permanent";
            let durationDisplay;
    
            if (ban.duration) {
                if (ban.duration.toString() === "5475d") {
                    durationDisplay = "Permanent";
                    badgeClass = "permanent";
                } else {
                    const durationString = ban.duration.toString();
                    const durationMatch = durationString.match(/(\d+)([a-z])/i);
                    
                    if (durationMatch) {
                        const value = parseInt(durationMatch[1], 10);
                        const unit = durationMatch[2].toLowerCase();
                        
                        if (unit === 'd' && value <= 3) {
                            badgeClass = "short";
                        } else if ((unit === 'd' && value <= 14) || unit === 'h') {
                            badgeClass = "medium";
                        } else if (unit === 'd' && value <= 30) {
                            badgeClass = "long";
                        } else {
                            badgeClass = "very-long";
                        }
                    } else {
                        badgeClass = "permanent";
                    }
                    
                    durationDisplay = ban.duration;
                }
            } else {
                durationDisplay = "Permanent";
                badgeClass = "permanent";
            }
    
            const durationBadge = `<span class="duration-badge ${badgeClass}">${durationDisplay}</span>`;
            
            const banItem = $(`
                <tr data-id="${ban.id}" data-ban-id="${ban.ban_id}">
                    <td><span class="ban-id">${ban.ban_id}</span></td>
                    <td>${escapeHtml(ban.target_name)}</td>
                    <td>${escapeHtml(ban.reason)}</td>
                    <td>${escapeHtml(ban.admin_name)}</td>
                    <td>${formatDate(ban.ban_date)}</td>
                    <td>${durationBadge}</td>
                    <td>
                        <div class="ban-actions">
                            <button class="edit-ban"><i class="fas fa-edit"></i> Edit</button>
                            <button class="unban-btn"><i class="fas fa-unlock"></i> Unban</button>
                        </div>
                    </td>
                </tr>
            `);
            
            banItem.find('.edit-ban').on('click', function() {
                const row = $(this).closest('tr');
                const banId = row.data('ban-id');
                const banData = getBanDataById(banId);
                
                if (banData) {
                    $('#editBanReason').val(banData.reason);
                    $('#editBanDuration').val(banData.duration || '');
                    $('#editBanId').val(banData.ban_id);
                    
                    $('#editBanModal').fadeIn(200).css('display', 'flex');
                }
            });
            
            banItem.find('.unban-btn').on('click', function() {
                const row = $(this).closest('tr');
                const banId = row.data('ban-id');
                
                // Disable the button during processing
                $(this).prop('disabled', true).html('<i class="fas fa-spinner fa-spin"></i> Processing...');
            
                $.post(`https://${GetParentResourceName()}/submitUnban`, JSON.stringify({
                    banId: banId
                }), function() {
                    showNotification('success', 'Player Unbanned', 'The player has been unbanned successfully.');
                    
                });
            });
            
            banListBody.append(banItem);
        });
    }
    
    function getBanDataById(banId) {
        return activeBans.find(ban => ban.ban_id === banId);
    }
    
    function formatDate(dateString) {
        const date = new Date(dateString);
        return `${date.getFullYear()}-${padZero(date.getMonth() + 1)}-${padZero(date.getDate())} ${padZero(date.getHours())}:${padZero(date.getMinutes())}`;
    }
    
    function padZero(num) {
        return num.toString().padStart(2, '0');
    }
    
    function escapeHtml(text) {
        if (!text) return '';
        
        const map = {
            '&': '&amp;',
            '<': '&lt;',
            '>': '&gt;',
            '"': '&quot;',
            "'": '&#039;'
        };
        
        return text.toString().replace(/[&<>"']/g, m => map[m]);
    }
    
    function switchTab(tabName) {
        $('.tab').removeClass('active');
        $(`.tab[data-tab="${tabName}"]`).addClass('active');
        
        $('.tab-content').removeClass('active').hide();
        $(`#${tabName}Tab`).show().addClass('active');
    }
    
    $('.tab').on('click', function() {
        const tabName = $(this).data('tab');
        
        $.post(`https://${GetParentResourceName()}/switchTab`, JSON.stringify({
            tab: tabName
        }));
        
        switchTab(tabName);
    });
    
    $('#closeButton').on('click', function() {
        $.post(`https://${GetParentResourceName()}/exitUI`, JSON.stringify({}));
    });
    
    $('#submitBanBtn').on('click', function() {
        if (!selectedPlayerId) {
            showNotification('error', 'Error', 'Please select a player to ban');
            return;
        }
        
        const reason = $('#banReason').val();
        if (!reason) {
            showNotification('error', 'Error', 'Please enter a ban reason');
            return;
        }
        
        const duration = $('#banDuration').val();
        
        $.post(`https://${GetParentResourceName()}/submitBan`, JSON.stringify({
            targetId: selectedPlayerId,
            reason: reason,
            duration: duration,
            offline: false
        }));
        
        $('#banReason').val('');
        $('#banDuration').val('');
        
        showNotification('success', 'Player Banned', 'The player has been banned successfully.');
    });
    
    $('#submitOfflineBanBtn').on('click', function() {
        const playerName = $('#offlinePlayerName').val();
        if (!playerName) {
            showNotification('error', 'Error', 'Please enter a player name');
            return;
        }
        
        const license = $('#offlineLicense').val();
        const license2 = $('#offlineLicense2').val();
        const steam = $('#offlineSteam').val();
        const discord = $('#offlineDiscord').val();
        const ip = $('#offlineIP').val();
        const xbl = $('#offlineXBL').val();
        
        if (!license && !license2 && !steam && !discord && !ip && !xbl) {
            showNotification('error', 'Error', 'Please enter at least one player identifier');
            return;
        }
        
        const reason = $('#offlineBanReason').val();
        if (!reason) {
            showNotification('error', 'Error', 'Please enter a ban reason');
            return;
        }
        
        const duration = $('#offlineBanDuration').val();
        
        $(this).prop('disabled', true).html('<i class="fas fa-spinner fa-spin"></i> Processing...');
        const btn = $(this);
        
        $.post(`https://${GetParentResourceName()}/submitBan`, JSON.stringify({
            playerName: playerName,
            license: license,
            license2: license2,
            steam: steam,
            discord: discord,
            ip: ip,
            xbl: xbl,
            reason: reason,
            duration: duration,
            offline: true
        }), function() {
            // Reset button state
            btn.prop('disabled', false).html('<i class="fas fa-user-slash"></i> Ban Offline Player');
            
            $('#offlinePlayerName').val('');
            $('#offlineLicense').val('');
            $('#offlineLicense2').val('');
            $('#offlineSteam').val('');
            $('#offlineDiscord').val('');
            $('#offlineIP').val('');
            $('#offlineXBL').val('');
            $('#offlineBanReason').val('');
            $('#offlineBanDuration').val(uiConfig.durations[0]?.value || '');
            
            showNotification('success', 'Offline Player Banned', 'The offline player has been banned successfully.');
        }).fail(function() {
            btn.prop('disabled', false).html('<i class="fas fa-user-slash"></i> Ban Offline Player');
            showNotification('error', 'Error', 'Failed to ban player. Please try again.');
        });
    });
    
    $('#submitEditBanBtn').on('click', function() {
        const banId = $('#editBanId').val();
        const reason = $('#editBanReason').val();
        const duration = $('#editBanDuration').val();
        
        if (!banId || !reason) {
            showNotification('error', 'Error', 'Ban ID and reason are required');
            return;
        }
        
        // Show processing state
        $(this).prop('disabled', true).html('<i class="fas fa-spinner fa-spin"></i> Processing...');
        
        $.post(`https://${GetParentResourceName()}/editBan`, JSON.stringify({
            ban_id: banId,
            reason: reason,
            duration: duration
        }), function() {
            $('#editBanModal').fadeOut(200);
            $('#submitEditBanBtn').prop('disabled', false).html('<i class="fas fa-save"></i> Save Changes');
            showNotification('success', 'Ban Updated', 'The ban has been updated successfully.');
            
        });
    });
    
    $('#closeEditModal').on('click', function() {
        $('#editBanModal').fadeOut(200);
    });
    
    $('#refreshBanList').on('click', function() {
        $(this).addClass('rotating');
        
        $.post(`https://${GetParentResourceName()}/refreshBanList`, JSON.stringify({}), function(response) { 
            setTimeout(() => {
                $('#refreshBanList').removeClass('rotating');
            }, 1000);
        });
    });
    
    $('#refreshPlayerList').on('click', function() {
        $(this).addClass('rotating');
        setTimeout(() => {
            $(this).removeClass('rotating');
        }, 1000);
        
        $.post(`https://${GetParentResourceName()}/getPlayers`, {}, function(response) {
            if (response.success && response.data) {
                renderPlayerList(response.data);
            }
        });
    });
    
    $('#playerSearch').on('input', function() {
        const searchTerm = $(this).val().toLowerCase();
        
        $('.player-item').each(function() {
            const playerName = $(this).find('.player-name').text().toLowerCase();
            const playerId = $(this).find('.player-id').text().toLowerCase();
            
            if (playerName.includes(searchTerm) || playerId.includes(searchTerm)) {
                $(this).show();
            } else {
                $(this).hide();
            }
        });
    });
    
    $('#banListSearch').on('input', function() {
        const searchTerm = $(this).val().toLowerCase();
        
        $('#banListBody tr').each(function() {
            const visible = Array.from($(this).find('td')).some(cell => 
                $(cell).text().toLowerCase().includes(searchTerm)
            );
            
            $(this).toggle(visible);
        });
    });
    

    
    $(document).keyup(function(e) {
        if (e.key === "Escape") {
            $.post(`https://${GetParentResourceName()}/exitUI`, JSON.stringify({}));
        }
    });
    
    $.post(`https://${GetParentResourceName()}/appLoaded`, JSON.stringify({}));
});