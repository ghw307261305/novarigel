/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 11-11-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
public class SlackMessageAction {
    private static String SLACK_TOKEN = System.Label.SLACK_TOKEN;
    
    public class SlackMessageRequest {
        @InvocableVariable(label='送信先 (Email または ChannelID)' description='Slack Email または DM ID' required=true)
        // 例: zhang@example.com  または U09LHAABVJ8
        public String recipientIdOrEmail;
        
        @InvocableVariable(label='返品注文番号' required=false)
        public String returnOrderNumber;
        
        @InvocableVariable(label='顧客名' required=false)
        public String customerName;
        
        @InvocableVariable(label='対象商品' required=false)
        public String productName;
        
        @InvocableVariable(label='返品理由' required=false)
        public String returnReason;
        
        @InvocableVariable(label='処理担当者' required=false)
        public String processorName;
        
        @InvocableVariable(label='登録日時' required=false)
        public String registrationDateTime;
    }
    
    public class SlackMessageResponse {
        @InvocableVariable(label='成功フラグ')
        public Boolean isSuccess;
        
        @InvocableVariable(label='エラーメッセージ')
        public String errorMessage;
        
        @InvocableVariable(label='送信先チャンネルID')
        public String targetChannelId;
        
        @InvocableVariable(label='Slack ユーザーID')
        public String slackUserId;
        
        @InvocableVariable(label='メッセージタイムスタンプ')
        public String messageTs;
    }
    
    @InvocableMethod(label='Slack 返品完了通知を送信'
                     description='Email または ID で返品完了通知を送信します'
                     category='Slack返品管理')
    public static List<SlackMessageResponse> sendNotification(List<SlackMessageRequest> requests) {
        List<SlackMessageResponse> responses = new List<SlackMessageResponse>();
        
        for (SlackMessageRequest request : requests) {
            SlackMessageResponse response = new SlackMessageResponse();
            
            try {
                String targetChannelId = request.recipientIdOrEmail;
                
                // ステップ1: Email の場合は User ID に変換
                if (isEmail(targetChannelId)) {
                    System.debug('Email が検出されました: ' + targetChannelId);
                    String userId = getUserIdByEmail(targetChannelId);
                    
                    if (String.isBlank(userId)) {
                        response.isSuccess = false;
                        response.errorMessage = 'Email: ' + targetChannelId + ' に対応する Slack ユーザーが見つかりませんでした';
                        responses.add(response);
                        continue;
                    }
                    
                    response.slackUserId = userId;
                    targetChannelId = userId;
                    System.debug('User ID を取得しました: ' + userId);
                }
                
                // ステップ2: User ID (U...) の場合は DM Channel を開く
                if (targetChannelId.startsWith('U')) {
                    System.debug('User ID が検出されました。DM チャンネルを開きます: ' + targetChannelId);
                    String dmChannelId = openDMChannel(targetChannelId);
                    
                    if (String.isBlank(dmChannelId)) {
                        response.isSuccess = false;
                        response.errorMessage = 'DM チャンネルの作成に失敗しました (User ID: ' + targetChannelId + ')';
                        responses.add(response);
                        continue;
                    }
                    
                    targetChannelId = dmChannelId;
                    System.debug('DM チャンネル ID を取得しました: ' + dmChannelId);
                }
                
                // ステップ3: Public Channel (C...) の場合は参加を試みる
                if (targetChannelId.startsWith('C')) {
                    System.debug('Public Channel が検出されました。参加を試みます: ' + targetChannelId);
                    joinChannel(targetChannelId);
                }
                
                response.targetChannelId = targetChannelId;
                
                // ステップ4: メッセージを構築して送信
                String messageText = buildReturnNotificationMessage(request);
                
                Map<String, Object> requestBody = new Map<String, Object>{
                    'channel' => targetChannelId,
                    'text' => messageText,
                    'blocks' => buildMessageBlocks(request)
                };
                
                HttpRequest req = new HttpRequest();
                req.setEndpoint('https://slack.com/api/chat.postMessage');
                req.setMethod('POST');
                req.setHeader('Content-Type', 'application/json');
                req.setHeader('Authorization', 'Bearer ' + SLACK_TOKEN);
                req.setBody(JSON.serialize(requestBody));
                req.setTimeout(120000);
                
                Http http = new Http();
                HttpResponse res = http.send(req);
                
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                
                if (res.getStatusCode() == 200 && (Boolean) responseMap.get('ok')) {
                    response.isSuccess = true;
                    response.messageTs = (String) responseMap.get('ts');
                    System.debug('メッセージ送信成功: ' + response.messageTs);
                } else {
                    response.isSuccess = false;
                    response.errorMessage = (String) responseMap.get('error');
                    System.debug('メッセージ送信失敗: ' + response.errorMessage);
                }
                
            } catch (Exception e) {
                response.isSuccess = false;
                response.errorMessage = e.getMessage();
                System.debug('通知送信エラー: ' + e.getMessage() + '\nStack Trace: ' + e.getStackTraceString());
            }
            
            responses.add(response);
        }
        
        return responses;
    }
    
    // Email かどうかを判定
    private static Boolean isEmail(String input) {
        if (String.isBlank(input)) {
            return false;
        }
        // 簡易的な Email 判定 (@ を含む)
        return input.contains('@');
    }
    
    // Email から Slack User ID を取得
    private static String getUserIdByEmail(String email) {
        try {
            // URL エンコード
            String encodedEmail = EncodingUtil.urlEncode(email, 'UTF-8');
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint('https://slack.com/api/users.lookupByEmail?email=' + encodedEmail);
            req.setMethod('GET');
            req.setHeader('Authorization', 'Bearer ' + SLACK_TOKEN);
            req.setTimeout(120000);
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            System.debug('Email 検索レスポンス: ' + res.getBody());
            
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            
            if (res.getStatusCode() == 200 && (Boolean) responseMap.get('ok')) {
                Map<String, Object> user = (Map<String, Object>) responseMap.get('user');
                String userId = (String) user.get('id');
                System.debug('User ID 取得成功: ' + userId);
                return userId;
            } else {
                String errorMsg = (String) responseMap.get('error');
                System.debug('User ID 取得失敗: ' + errorMsg);
                return null;
            }
            
        } catch (Exception e) {
            System.debug('Email から User ID 取得エラー: ' + e.getMessage());
            return null;
        }
    }
    
    // ユーザーとの DM チャンネルを開く
    private static String openDMChannel(String userId) {
        try {
            Map<String, Object> requestBody = new Map<String, Object>{
                'users' => userId
            };
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint('https://slack.com/api/conversations.open');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Authorization', 'Bearer ' + SLACK_TOKEN);
            req.setBody(JSON.serialize(requestBody));
            req.setTimeout(120000);
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            System.debug('DM チャンネル作成レスポンス: ' + res.getBody());
            
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            
            if (res.getStatusCode() == 200 && (Boolean) responseMap.get('ok')) {
                Map<String, Object> channel = (Map<String, Object>) responseMap.get('channel');
                String channelId = (String) channel.get('id');
                System.debug('DM チャンネル作成成功: ' + channelId);
                return channelId;
            } else {
                String errorMsg = (String) responseMap.get('error');
                System.debug('DM チャンネル作成失敗: ' + errorMsg);
                return null;
            }
            
        } catch (Exception e) {
            System.debug('DM チャンネル作成エラー: ' + e.getMessage());
            return null;
        }
    }
    
    // Bot を Channel に参加させる (Public Channel のみ)
    private static void joinChannel(String channelId) {
        try {
            Map<String, Object> requestBody = new Map<String, Object>{
                'channel' => channelId
            };
            
            HttpRequest req = new HttpRequest();
 	           req.setEndpoint('https://slack.com/api/conversations.join');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Authorization', 'Bearer ' + SLACK_TOKEN);
            req.setBody(JSON.serialize(requestBody));
            req.setTimeout(120000);
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            System.debug('Join channel レスポンス: ' + res.getBody());
        } catch (Exception e) {
            System.debug('Failed to join channel: ' + e.getMessage());
        }
    }
    
    // 返品通知メッセージを構築
    private static String buildReturnNotificationMessage(SlackMessageRequest request) {
        String message = '返品手続きが完了しました。以下の内容をご確認ください。\n\n';
        message += '・返品注文番号：' + (String.isNotBlank(request.returnOrderNumber) ? request.returnOrderNumber : '未設定') + '\n';
        message += '・顧客名：' + (String.isNotBlank(request.customerName) ? request.customerName : '未設定') + '\n';
        message += '・対象商品：' + (String.isNotBlank(request.productName) ? request.productName : '未設定') + '\n';
        message += '・返品理由：' + (String.isNotBlank(request.returnReason) ? request.returnReason : '未設定') + '\n';
        message += '・処理担当者：' + (String.isNotBlank(request.processorName) ? request.processorName : '未設定') + '\n';
        message += '・登録日時：' + (String.isNotBlank(request.registrationDateTime) ? request.registrationDateTime : '未設定') + '\n\n';
        message += '顧客には返品完了の案内が送信されています。\n';
        message += '必要に応じて在庫・返金・再出荷の対応をお願いします。';
        
        return message;
    }
    
    // Slack Block Kit 形式でメッセージを構築
    private static List<Object> buildMessageBlocks(SlackMessageRequest request) {
        List<Object> blocks = new List<Object>();
        
        // ヘッダー
        blocks.add(new Map<String, Object>{
            'type' => 'header',
            'text' => new Map<String, Object>{
                'type' => 'plain_text',
                'text' => '✅ 返品手続き完了通知',
                'emoji' => true
            }
        });
        
        blocks.add(new Map<String, Object>{'type' => 'divider'});
        
        // 返品情報セクション
        blocks.add(new Map<String, Object>{
            'type' => 'section',
            'text' => new Map<String, Object>{
                'type' => 'mrkdwn',
                'text' => '返品手続きが完了しました。以下の内容をご確認ください。'
            }
        });
        
        // 詳細フィールド
        List<Object> fields = new List<Object>();
        fields.add(new Map<String, Object>{
            'type' => 'mrkdwn',
            'text' => '*返品注文番号*\n' + (String.isNotBlank(request.returnOrderNumber) ? request.returnOrderNumber : '未設定')
        });
        fields.add(new Map<String, Object>{
            'type' => 'mrkdwn',
            'text' => '*顧客名*\n' + (String.isNotBlank(request.customerName) ? request.customerName : '未設定')
        });
        fields.add(new Map<String, Object>{
            'type' => 'mrkdwn',
            'text' => '*対象商品*\n' + (String.isNotBlank(request.productName) ? request.productName : '未設定')
        });
        fields.add(new Map<String, Object>{
            'type' => 'mrkdwn',
            'text' => '*返品理由*\n' + (String.isNotBlank(request.returnReason) ? request.returnReason : '未設定')
        });
        fields.add(new Map<String, Object>{
            'type' => 'mrkdwn',
            'text' => '*処理担当者*\n' + (String.isNotBlank(request.processorName) ? request.processorName : '未設定')
        });
        fields.add(new Map<String, Object>{
            'type' => 'mrkdwn',
            'text' => '*登録日時*\n' + (String.isNotBlank(request.registrationDateTime) ? request.registrationDateTime : '未設定')
        });
        
        blocks.add(new Map<String, Object>{
            'type' => 'section',
            'fields' => fields
        });
        
        blocks.add(new Map<String, Object>{'type' => 'divider'});
        
        // 注意事項
        blocks.add(new Map<String, Object>{
            'type' => 'section',
            'text' => new Map<String, Object>{
                'type' => 'mrkdwn',
                'text' => '📧 顧客には返品完了の案内が送信されています。\n💡 必要に応じて在庫・返金・再出荷の対応をお願いします。'
            }
        });
        
        return blocks;
    }
}