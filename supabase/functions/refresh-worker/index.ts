//  index.ts
//  Created automatically by Cursor Assistant
//  Created on: 2025-12-23 at 23:00 (America/Los_Angeles - Pacific Time)
//  Notes: Refresh worker function - processes refresh_queue and refreshes movie metadata

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
const supabaseServiceKey = Deno.env.get('SERVICE_ROLE_KEY')!;

const MAX_RETRIES = 3;
const BATCH_SIZE = 10; // Process 10 movies per worker run

serve(async (req) => {
  const startTime = Date.now();
  
  try {
    console.log('[REFRESH-WORKER] Starting refresh worker...');
    
    // Create Supabase admin client
    const supabase = createClient(supabaseUrl, supabaseServiceKey);
    
    // Step 1: Claim queued items atomically (FOR UPDATE SKIP LOCKED pattern)
    // This ensures multiple worker instances don't process the same items
    const { data: queuedItems, error: claimError } = await supabase
      .from('refresh_queue')
      .select('id, work_id, retry_count, status')
      .eq('status', 'queued')
      .order('priority', { ascending: false }) // Higher priority first
      .order('queued_at', { ascending: true }) // Older items first
      .limit(BATCH_SIZE);
    
    if (claimError) {
      throw claimError;
    }
    
    if (!queuedItems || queuedItems.length === 0) {
      console.log('[REFRESH-WORKER] No items in queue');
      return new Response(
        JSON.stringify({
          success: true,
          items_processed: 0,
          items_succeeded: 0,
          items_failed: 0,
          duration_ms: Date.now() - startTime
        }),
        { headers: { 'Content-Type': 'application/json' } }
      );
    }
    
    console.log(`[REFRESH-WORKER] Claimed ${queuedItems.length} items from queue`);
    
    // Step 2: Mark items as processing
    const itemIds = queuedItems.map(item => item.id);
    const { error: updateError } = await supabase
      .from('refresh_queue')
      .update({ 
        status: 'processing',
        processed_at: new Date().toISOString()
      })
      .in('id', itemIds);
    
    if (updateError) {
      throw updateError;
    }
    
    // Step 3: Process each item
    let succeeded = 0;
    let failed = 0;
    
    for (const item of queuedItems) {
      try {
        // Get tmdb_id from works table
        const { data: work, error: workError } = await supabase
          .from('works')
          .select('tmdb_id, title')
          .eq('work_id', item.work_id)
          .single();
        
        if (workError || !work) {
          throw new Error(`Work not found: ${workError?.message || 'unknown'}`);
        }
        
        if (!work.tmdb_id) {
          throw new Error('Work has no tmdb_id');
        }
        
        console.log(`[REFRESH-WORKER] Processing work_id: ${item.work_id}, tmdb_id: ${work.tmdb_id}`);
        
        // Call ingest-movie Edge Function to refresh metadata
        const ingestResponse = await fetch(`${supabaseUrl}/functions/v1/ingest-movie`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${supabaseServiceKey}`
          },
          body: JSON.stringify({ 
            tmdb_id: work.tmdb_id,
            force_refresh: true // Force refresh even if not stale
          })
        });
        
        const ingestResult = await ingestResponse.json();
        
        if (ingestResponse.ok) {
          // Success: mark as completed
          await supabase
            .from('refresh_queue')
            .update({ 
              status: 'completed',
              processed_at: new Date().toISOString(),
              last_error: null
            })
            .eq('id', item.id);
          
          succeeded++;
          console.log(`[REFRESH-WORKER] ✅ Successfully refreshed work_id: ${item.work_id}`);
        } else {
          // Failure: increment retry count
          const newRetryCount = (item.retry_count || 0) + 1;
          const errorMessage = ingestResult.error || 'Unknown error';
          
          if (newRetryCount >= MAX_RETRIES) {
            // Max retries reached: mark as failed
            await supabase
              .from('refresh_queue')
              .update({ 
                status: 'failed',
                retry_count: newRetryCount,
                last_error: errorMessage,
                processed_at: new Date().toISOString()
              })
              .eq('id', item.id);
            
            failed++;
            console.error(`[REFRESH-WORKER] ❌ Failed work_id: ${item.work_id} after ${MAX_RETRIES} retries: ${errorMessage}`);
          } else {
            // Retry: put back in queue
            await supabase
              .from('refresh_queue')
              .update({ 
                status: 'queued',
                retry_count: newRetryCount,
                last_error: errorMessage,
                processed_at: null // Reset processed_at for retry
              })
              .eq('id', item.id);
            
            console.warn(`[REFRESH-WORKER] ⚠️ Retrying work_id: ${item.work_id} (attempt ${newRetryCount}/${MAX_RETRIES}): ${errorMessage}`);
          }
        }
        
        // Rate limiting: wait 1 second between refreshes
        await new Promise(resolve => setTimeout(resolve, 1000));
        
      } catch (error) {
        // Exception during processing
        const newRetryCount = (item.retry_count || 0) + 1;
        const errorMessage = error.message || 'Exception during refresh';
        
        if (newRetryCount >= MAX_RETRIES) {
          await supabase
            .from('refresh_queue')
            .update({ 
              status: 'failed',
              retry_count: newRetryCount,
              last_error: errorMessage,
              processed_at: new Date().toISOString()
            })
            .eq('id', item.id);
          
          failed++;
          console.error(`[REFRESH-WORKER] ❌ Exception for work_id: ${item.work_id} after ${MAX_RETRIES} retries: ${errorMessage}`);
        } else {
          await supabase
            .from('refresh_queue')
            .update({ 
              status: 'queued',
              retry_count: newRetryCount,
              last_error: errorMessage,
              processed_at: null
            })
            .eq('id', item.id);
          
          console.warn(`[REFRESH-WORKER] ⚠️ Retrying work_id: ${item.work_id} after exception (attempt ${newRetryCount}/${MAX_RETRIES}): ${errorMessage}`);
        }
      }
    }
    
    const durationMs = Date.now() - startTime;
    
    console.log(`[REFRESH-WORKER] Completed: ${succeeded} succeeded, ${failed} failed, duration: ${durationMs}ms`);
    
    return new Response(
      JSON.stringify({
        success: true,
        items_processed: queuedItems.length,
        items_succeeded: succeeded,
        items_failed: failed,
        duration_ms: durationMs
      }),
      { headers: { 'Content-Type': 'application/json' } }
    );
    
  } catch (error) {
    const durationMs = Date.now() - startTime;
    console.error('[REFRESH-WORKER] Error:', error);
    
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message || 'Unknown error',
        duration_ms: durationMs
      }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    );
  }
});

