use channel::Receiver;
use futures::StreamExt;
use logger::prelude::*;
use std::sync::mpsc::SyncSender;

#[derive(Debug)]
pub enum IsSyncingMessage {
    Check,
    Terminate(SyncSender<()>),
}

pub struct IsSyncingChecker {
    osmosisd_endpoint: String,
    receiver: Receiver<IsSyncingMessage>,
}

impl IsSyncingChecker {
    pub fn new(osmosisd_endpoint: String, receiver: Receiver<IsSyncingMessage>) -> Self {
        Self {
            osmosisd_endpoint,
            receiver,
        }
    }
    pub async fn run(mut self) {
        while let Some(message) = self.receiver.next().await {
            match message {
                IsSyncingMessage::Check => {
                    match osmosiscli::get_client(&self.osmosisd_endpoint)
                        .lock()
                        .await
                        .fetch_syncing()
                        .await
                    {
                        Ok(syncing) => {
                            if syncing {
                                error!(
                                    "the osmosis daemon: {} is syncing",
                                    self.osmosisd_endpoint.as_str()
                                );
                            } else {
                                info!(
                                    "the osmosis daemon: {} is synced",
                                    self.osmosisd_endpoint.as_str()
                                );
                            }
                        }
                        Err(err) => {
                            error!("{}", err);
                        }
                    }
                }
                IsSyncingMessage::Terminate(sender) => {
                    info!("is syncing checker will be terminated soon...");
                    let _ = sender.send(());
                    break;
                }
            }
        }
    }
}
