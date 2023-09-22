const std = @import("std");

pub const TELEGRAM_TOKEN = "";
pub const TELEGRAM_CHAT_ID = "";
pub const COINGECKO_API = std.Uri.parse("https://api.coingecko.com/api/v3/simple/price?ids=the-open-network&vs_currencies=usd") catch unreachable;
